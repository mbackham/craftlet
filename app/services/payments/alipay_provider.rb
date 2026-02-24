# frozen_string_literal: true

module Payments
  # Alipay provider skeleton.
  #
  # Mock mode active when ALIPAY_APP_ID is blank.
  # Replace mock_* methods with alipay gem calls next week.
  class AlipayProvider < BaseProvider
    CONFIG = Rails.application.config.payment_providers[:alipay]

    def create_payment(payment:)
      if mock_mode?
        Rails.logger.info("[AlipayProvider] MOCK create_payment for payment##{payment.id}")
        raw = mock_payment_response(payment)
        ok_response(
          provider_trade_no: raw[:trade_no],
          raw: raw
        )
      else
        err_response("Alipay real integration not yet implemented")
      end
    rescue => e
      Rails.logger.error("[AlipayProvider] create_payment error: #{e.message}")
      err_response(e.message)
    end

    def create_refund(refund:)
      if mock_mode?
        Rails.logger.info("[AlipayProvider] MOCK create_refund for refund##{refund.id}")
        raw = mock_refund_response(refund)
        ok_response(
          provider_refund_no: raw[:out_request_no],
          raw: raw
        )
      else
        err_response("Alipay real refund integration not yet implemented")
      end
    rescue => e
      Rails.logger.error("[AlipayProvider] create_refund error: #{e.message}")
      err_response(e.message)
    end

    def verify_callback(headers:, payload:)
      return true if mock_mode?
      # TODO: verify Alipay RSA2 signature via alipay gem
      false
    end

    private

    def mock_mode?
      CONFIG[:app_id].blank?
    end

    def mock_payment_response(payment)
      {
        code:            "10000",
        msg:             "Success",
        trade_no:        "ALI_MOCK_#{SecureRandom.hex(8).upcase}",
        out_trade_no:    payment.idempotency_key,
        total_amount:    payment.amount.to_s,
        gmt_payment:     Time.current.strftime("%Y-%m-%d %H:%M:%S")
      }
    end

    def mock_refund_response(refund)
      {
        code:           "10000",
        msg:            "Success",
        trade_no:       refund.payment.provider_trade_no,
        out_request_no: "ALIR_MOCK_#{SecureRandom.hex(8).upcase}",
        refund_fee:     refund.amount.to_s
      }
    end
  end
end
