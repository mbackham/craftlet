# frozen_string_literal: true

module Refunds
  # Dispatches a refund to the appropriate payment provider (WeChat / Alipay).
  # Called by Refunds::ApproveService after admin approval.
  #
  # Idempotency:
  #   - Skips execution if refund is not in "pending" status.
  #   - provider_refund_no is written atomically; a second identical call will
  #     find the refund already succeeded and exit early.
  #
  # Error classification:
  #   RETRYABLE_ERRORS   — transient network / provider errors → keep pending, re-enqueue
  #   NON_RETRYABLE_MSGS — business errors (e.g. already refunded) → mark failed immediately
  class ProcessRefundJob < ApplicationJob
    queue_as :default

    # Sidekiq retry config: 5 attempts, exponential back-off
    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    # Provider error substrings that should NOT be retried (need human review)
    NON_RETRYABLE_MSGS = %w[
      INVALID_REQUEST
      REFUND_FAILED
      already_refunded
      out_of_refund_period
    ].freeze

    def perform(refund_id)
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
          response_payload:   response[:raw].as_json
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

      Rails.logger.info(
        "[Refunds::ProcessRefundJob] Refund ##{refund.id} succeeded — provider_refund_no: #{refund.provider_refund_no}"
      )
    end

    def handle_failure(refund, error_message)
      if non_retryable?(error_message)
        # Mark as failed immediately — human intervention required
        refund.update!(status: "failed", response_payload: { error: error_message }.as_json)

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
        # Retryable — let Sidekiq retry via retry_on; log a warning
        Rails.logger.warn(
          "[Refunds::ProcessRefundJob] Refund ##{refund.id} provider error (retryable): #{error_message}"
        )
        raise error_message
      end
    end

    def non_retryable?(error_message)
      return false if error_message.blank?
      NON_RETRYABLE_MSGS.any? { |msg| error_message.include?(msg) }
    end
  end
end
