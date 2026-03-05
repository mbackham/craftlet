# frozen_string_literal: true

module Payments
  # Handles inbound payment provider callback notifications (WeChat / Alipay).
  #
  # Responsibilities:
  #   1. Locate the Refund by provider_refund_no (idempotency key)
  #   2. Guard against replay attacks (already-succeeded refunds are ignored)
  #   3. Transition refund → succeeded + order → refunded inside a transaction
  #   4. Write AuditLog for full traceability
  #
  # Usage:
  #   result = Payments::HandleCallbackService.new(
  #     channel:            "wechat",         # or "alipay"
  #     provider_refund_no: "WXR_...",
  #     notify_payload:     parsed_hash        # raw callback params
  #   ).call
  #
  #   result.success?   # => true / false
  #   result.error      # => error string or nil
  #   result.replayed?  # => true if this was a duplicate callback
  class HandleCallbackService
    attr_reader :error

    def initialize(channel:, provider_refund_no:, notify_payload: {})
      @channel            = channel
      @provider_refund_no = provider_refund_no
      @notify_payload     = notify_payload
      @success            = false
      @replayed           = false
      @error              = nil
    end

    def call
      refund = find_refund
      return fail_with("Refund not found for provider_refund_no: #{@provider_refund_no}") unless refund

      # Replay guard: already succeeded — return success immediately (idempotent)
      if refund.status == "succeeded"
        Rails.logger.info(
          "[HandleCallbackService] Replay detected for refund ##{refund.id} — already succeeded"
        )
        @success  = true
        @replayed = true
        return self
      end

      # Only transition from pending state
      unless refund.status == "pending"
        return fail_with(
          "Unexpected refund status \"#{refund.status}\" for provider_refund_no: #{@provider_refund_no}"
        )
      end

      process_callback!(refund)
      self
    rescue => e
      Rails.logger.error("[HandleCallbackService] Unexpected error: #{e.message}")
      fail_with(e.message)
      self
    end

    def success?
      @success
    end

    def replayed?
      @replayed
    end

    private

    def find_refund
      Refund.find_by(provider_refund_no: @provider_refund_no)
    end

    def process_callback!(refund)
      # Idempotency: provider_refund_no unique index + pessimistic locking
      refund.with_lock do
        # Double-check inside transaction
        if refund.status == "succeeded"
          @success  = true
          @replayed = true
          return
        end

        old_status = refund.status

        refund.update!(
          status:         "succeeded",
          succeeded_at:   Time.current,
          notify_payload: @notify_payload.as_json
        )

        # Propagate to order — AASM guard prevents double transition
        order = refund.order
        order.refund! if order.may_refund?

        AuditService.log!(
          action:   "callback_refund_succeeded",
          actor:    nil, # system / provider callback
          target:   refund,
          before:   { status: old_status },
          after:    { status: "succeeded" },
          metadata: {
            action_type:       "payment_callback",
            channel:           @channel,
            provider_refund_no: @provider_refund_no
          }
        )

        @success = true
      end
    end

    def fail_with(message)
      @error   = message
      @success = false
      self
    end
  end
end
