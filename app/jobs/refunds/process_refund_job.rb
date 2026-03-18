# frozen_string_literal: true

module Refunds
  # Dispatches a refund to the appropriate payment provider (WeChat / Alipay).
  # Called by Refunds::ApproveService after admin approval.
  #
  # Idempotency:
  #   - Skips execution if refund is not in "pending" status.
  #   - provider_refund_no is written atomically; a second identical call will
  #     find the refund already succeeded and exit early.
  class ProcessRefundJob < ApplicationJob
    queue_as :default

    # Provider error substrings that should NOT be retried (need human review)
    NON_RETRYABLE_MSGS = %w[
      INVALID_REQUEST
      REFUND_FAILED
      already_refunded
      out_of_refund_period
    ].freeze

    # 抛弃不可反序列化的参数错误
    discard_on ActiveJob::DeserializationError

    # 最终尝试耗尽后的处理机制：更新状态并将错误堆栈写入 failure_reason
    retry_on StandardError, attempts: 5, wait: :polynomially_longer do |job, error|
      refund_id = job.arguments.first
      refund = Refund.find_by(id: refund_id)
      next unless refund && refund.status == "pending"

      refund.update!(
        status:           "failed",
        failure_reason:   "Max retries exhausted. Last error: #{error.message}".truncate(500),
        response_payload: (refund.response_payload || {}).merge(
          final_error:  error.class.to_s,
          backtrace:    error.backtrace&.first(5),
          exhausted_at: Time.current.iso8601
        ).as_json
      )

      AuditService.log!(
        action:   "refund_job_exhausted",
        actor:    nil,
        target:   refund,
        metadata: { detail: error.message }
      )
    end

    # 捕获单次异常，记录 failure_reason 并重新抛出以便进行下一次重试
    around_perform do |job, block|
      block.call
    rescue => e
      refund_id = job.arguments.first
      refund = Refund.find_by(id: refund_id)
      if refund && refund.status == "pending"
        # 截断以确保不超过 varchar(500) 限制
        refund.update!(failure_reason: "[#{Time.current}] #{e.class}: #{e.message}".truncate(500))
      end
      raise e # 重新抛出触发重试机制
    end

    def perform(refund_id, request_id: nil)
      # 注入上下文日志供后续链路查询
      Rails.logger.tagged("request_id=#{request_id}") do
        refund = Refund.find_by(id: refund_id)

        if refund.nil?
          Rails.logger.warn("[Refunds::ProcessRefundJob] Refund ##{refund_id} not found — skipping")
          return
        end

        unless refund.status == "pending"
          Rails.logger.info(
            "[Refunds::ProcessRefundJob] Refund ##{refund.id} is \"#{refund.status}\" — skipping (idempotent)"
          )
          return
        end

        Rails.logger.info("[Refunds::ProcessRefundJob] Processing refund ##{refund.id} via #{refund.payment.channel}")

        provider = Payments::ProviderFactory.for(refund.payment.channel)
        response = provider.create_refund(refund: refund)

        if response[:success]
          handle_success(refund, response)
        else
          handle_failure(refund, response[:error])
        end
      end
    end

    private

    def handle_success(refund, response)
      ActiveRecord::Base.transaction do
        refund.lock!

        # Double-check idempotency inside the transaction
        return if refund.status == "succeeded"

        refund.update!(
          status:             "succeeded",
          succeeded_at:       Time.current,
          provider_refund_no: response[:provider_refund_no],
          response_payload:   response[:raw].as_json,
          failure_reason:     nil # 清空以往失败记录
        )

        # Propagate refunded state to the order (AASM guard: only if not already refunded)
        order = refund.order
        order.refund! if order.may_refund?

        AuditService.log!(
          action:   "process_refund_succeeded",
          actor:    nil, # system action
          target:   refund,
          before:   { status: "pending" },
          after:    { status: "succeeded", provider_refund_no: response[:provider_refund_no] },
          metadata: {
            action_type:       "refund_processing",
            payment_channel:   refund.payment.channel,
            provider_refund_no: response[:provider_refund_no]
          }
        )
      end

      # === 资金监控：事务提交后执行，不影响退款主流程 ===
      begin
        FundMonitoring::LargeAmountDetector.call(refund)
      rescue => e
        Rails.logger.warn("[FundMonitoring] LargeAmountDetector error for Refund##{refund.id}: #{e.message}")
      end

      begin
        FundMonitoring::FrequentRefundDetector.call(refund)
      rescue => e
        Rails.logger.warn("[FundMonitoring] FrequentRefundDetector error for Refund##{refund.id}: #{e.message}")
      end

      Rails.logger.info(
        "[Refunds::ProcessRefundJob] Refund ##{refund.id} succeeded — provider_refund_no: #{refund.provider_refund_no}"
      )
    end

    def handle_failure(refund, error_message)
      if non_retryable?(error_message)
        # Mark as failed immediately — human intervention required
        refund.update!(
          status:           "failed",
          failure_reason:   "Non-retryable error: #{error_message}".truncate(500),
          response_payload: { error: error_message }.as_json
        )

        AuditService.log!(
          action:   "process_refund_failed",
          actor:    nil,
          target:   refund,
          before:   { status: "pending" },
          after:    { status: "failed" },
          metadata: { action_type: "refund_processing", error: error_message, non_retryable: true }
        )

        Rails.logger.error(
          "[Refunds::ProcessRefundJob] Refund ##{refund.id} FAILED (non-retryable): #{error_message}"
        )
      else
        # Retryable — raise string error, caught by around_perform & retry_on
        Rails.logger.warn(
          "[Refunds::ProcessRefundJob] Refund ##{refund.id} provider error (retryable): #{error_message}"
        )
        raise StandardError, error_message
      end
    end

    def non_retryable?(error_message)
      return false if error_message.blank?
      NON_RETRYABLE_MSGS.any? { |msg| error_message.include?(msg) }
    end
  end
end
