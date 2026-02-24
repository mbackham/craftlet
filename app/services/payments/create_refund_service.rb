# frozen_string_literal: true

module Payments
  # Creates a Refund record and calls the appropriate provider.
  #
  # Usage:
  #   result = Payments::CreateRefundService.new(
  #     payment: payment,
  #     amount:  payment.amount,
  #     reason:  "customer_request",
  #     requested_by: admin_user  # optional
  #   ).call
  #
  #   result.success?   # => true / false
  #   result.refund     # => Refund instance
  #   result.error      # => error string or nil
  class CreateRefundService
    attr_reader :refund, :error

    def initialize(payment:, amount:, reason: nil, requested_by: nil)
      @payment      = payment
      @amount       = amount
      @reason       = reason
      @requested_by = requested_by
      @refund       = nil
      @error        = nil
    end

    def call
      validate_input!

      ActiveRecord::Base.transaction do
        @refund = build_refund
        @refund.save!

        provider = ProviderFactory.for(@payment.channel)
        response = provider.create_refund(refund: @refund)

        if response[:success]
          @refund.update!(
            provider_refund_no: response[:provider_refund_no],
            status:             "pending",
            request_payload:    build_request_payload,
            response_payload:   response[:raw].as_json
          )
        else
          @error = response[:error]
          raise ActiveRecord::Rollback
        end
      end

      self
    rescue ArgumentError => e
      @error = e.message
      self
    rescue ActiveRecord::RecordInvalid => e
      @error = e.message
      self
    end

    def success?
      @error.nil? && @refund&.persisted?
    end

    private

    def validate_input!
      raise ArgumentError, "支付记录状态不支持退款 (当前: #{@payment.status})" unless @payment.status.in?(%w[paid refunded])
      raise ArgumentError, "退款金额不能大于支付金额" if @amount > @payment.amount
      raise ArgumentError, "退款金额必须大于 0" if @amount <= 0
    end

    def build_refund
      refund = Refund.new(
        order:          @payment.order,
        payment:        @payment,
        amount:         @amount,
        reason:         @reason,
        status:         "init",
        idempotency_key: "ref_#{@payment.idempotency_key}_#{SecureRandom.hex(6)}"
      )
      if @requested_by
        refund.requested_by_type = @requested_by.class.name
        refund.requested_by_id   = @requested_by.id
      end
      refund
    end

    def build_request_payload
      {
        payment_id:        @payment.id,
        provider_trade_no: @payment.provider_trade_no,
        refund_amount:     @amount,
        reason:            @reason
      }.as_json
    end
  end
end
