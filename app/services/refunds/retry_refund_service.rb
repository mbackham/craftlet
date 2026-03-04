# frozen_string_literal: true

module Refunds
  # Retries a failed refund by resetting its status and re-enqueuing ProcessRefundJob.
  #
  # Usage:
  #   result = Refunds::RetryRefundService.new(
  #     refund:     refund,
  #     admin_user: current_admin_user,
  #     request:    request
  #   ).call
  class RetryRefundService
    attr_reader :error

    def initialize(refund:, admin_user:, comment: nil, request: nil)
      @refund     = refund
      @admin_user = admin_user
      @comment    = comment
      @request    = request
      @error      = nil
    end

    def call
      validate!

      ActiveRecord::Base.transaction do
        @refund.lock!

        unless @refund.status == "failed"
          raise InvalidStateError, "退款状态不允许重试（当前: #{@refund.status}）"
        end

        @refund.update!(
          status:           "pending",
          response_payload: {}  # clear old response
        )

        AuditService.log!(
          action:   "refund_retry",
          actor:    @admin_user,
          target:   @refund,
          before:   { status: "failed" },
          after:    { status: "pending" },
          metadata: { refund_id: @refund.id, order_id: @refund.order_id, comment: @comment }.compact,
          request:  @request
        )
      end

      # Enqueue outside transaction to avoid job running before commit
      Refunds::ProcessRefundJob.perform_later(@refund.id)

      self
    rescue InvalidStateError => e
      @error = e.message
      self
    rescue ActiveRecord::RecordInvalid => e
      @error = e.message
      self
    end

    def success?
      @error.nil?
    end

    private

    class InvalidStateError < StandardError; end

    def validate!
      unless @refund.status == "failed"
        raise InvalidStateError, "退款状态不允许重试（当前: #{@refund.status}）"
      end
    end
  end
end
