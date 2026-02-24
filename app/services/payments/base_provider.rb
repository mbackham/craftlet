# frozen_string_literal: true

module Payments
  # Abstract base provider. All payment channel providers must inherit from this
  # and implement the three interface methods below.
  #
  # Response contract for create_payment / create_refund:
  #   {
  #     success:           Boolean,
  #     provider_trade_no: String | nil,   # only for create_payment
  #     provider_refund_no: String | nil,  # only for create_refund
  #     raw:               Hash,           # full raw response from provider
  #     error:             String | nil
  #   }
  class BaseProvider
    # @param payment [Payment]
    # @return [Hash] response contract (see above)
    def create_payment(payment:)
      raise NotImplementedError, "#{self.class}#create_payment is not implemented"
    end

    # @param refund  [Refund]
    # @return [Hash] response contract (see above)
    def create_refund(refund:)
      raise NotImplementedError, "#{self.class}#create_refund is not implemented"
    end

    # Verify an inbound callback/notification from the provider.
    # @param headers [Hash]
    # @param payload [Hash]
    # @return [Boolean]
    def verify_callback(headers:, payload:)
      raise NotImplementedError, "#{self.class}#verify_callback is not implemented"
    end

    protected

    # Merge base response fields to avoid repetition in subclasses.
    def ok_response(extra = {})
      { success: true, error: nil }.merge(extra)
    end

    def err_response(message)
      { success: false, error: message, raw: {} }
    end
  end
end
