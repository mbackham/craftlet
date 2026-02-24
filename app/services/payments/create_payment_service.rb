# frozen_string_literal: true

module Payments
  # Creates a Payment record and calls the appropriate provider.
  #
  # Usage:
  #   result = Payments::CreatePaymentService.new(order: order, channel: "wechat").call
  #   result.success?       # => true / false
  #   result.payment        # => Payment instance
  #   result.error          # => error string or nil
  class CreatePaymentService
    attr_reader :payment, :error

    def initialize(order:, channel:)
      @order   = order
      @channel = channel.to_s
      @payment = nil
      @error   = nil
    end

    def call
      ActiveRecord::Base.transaction do
        @payment = build_payment
        @payment.save!

        provider = ProviderFactory.for(@channel)
        response = provider.create_payment(payment: @payment)

        if response[:success]
          @payment.update!(
            provider_trade_no: response[:provider_trade_no],
            status:            "pending",
            request_payload:   build_request_payload,
            response_payload:  response[:raw].as_json
          )
        else
          @error = response[:error]
          raise ActiveRecord::Rollback
        end
      end

      self
    rescue ActiveRecord::RecordInvalid => e
      @error = e.message
      self
    end

    def success?
      @error.nil? && @payment&.persisted?
    end

    private

    def build_payment
      Payment.new(
        order:           @order,
        channel:         @channel,
        amount:          @order.total_amount,
        currency:        @order.currency,
        status:          "init",
        idempotency_key: "pay_#{@order.order_no}_#{SecureRandom.hex(6)}"
      )
    end

    def build_request_payload
      {
        channel:  @channel,
        order_no: @order.order_no,
        amount:   @payment.amount,
        currency: @payment.currency
      }.as_json
    end
  end
end
