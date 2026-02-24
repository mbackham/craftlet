# frozen_string_literal: true

module Payments
  # WeChat Pay provider skeleton.
  #
  # In mock mode (when WECHAT_MCH_ID is blank) all calls return synthetic data
  # so the rest of the pipeline can be exercised without real credentials.
  # Replace the `mock_*` methods with real WechatPay / wx_pay gem calls next week.
  class WechatProvider < BaseProvider
    CONFIG = Rails.application.config.payment_providers[:wechat]

    def create_payment(payment:)
      request = build_payment_request(payment)

      if mock_mode?
        Rails.logger.info("[WechatProvider] MOCK create_payment for payment##{payment.id}")
        raw = mock_payment_response(payment)
        ok_response(
          provider_trade_no: raw[:transaction_id],
          raw: raw
        )
      else
        # TODO: replace with real WeChat Pay JSAPI/Native call
        err_response("WeChat Pay real integration not yet implemented")
      end
    rescue => e
      Rails.logger.error("[WechatProvider] create_payment error: #{e.message}")
      err_response(e.message)
    end

    def create_refund(refund:)
      if mock_mode?
        Rails.logger.info("[WechatProvider] MOCK create_refund for refund##{refund.id}")
        raw = mock_refund_response(refund)
        ok_response(
          provider_refund_no: raw[:refund_id],
          raw: raw
        )
      else
        err_response("WeChat Pay real refund integration not yet implemented")
      end
    rescue => e
      Rails.logger.error("[WechatProvider] create_refund error: #{e.message}")
      err_response(e.message)
    end

    def verify_callback(headers:, payload:)
      return true if mock_mode?
      # TODO: verify WeChat Pay HMAC-SHA256 signature
      false
    end

    private

    def mock_mode?
      CONFIG[:mch_id].blank?
    end

    def build_payment_request(payment)
      {
        appid:        CONFIG[:app_id],
        mch_id:       CONFIG[:mch_id],
        out_trade_no: payment.idempotency_key,
        total_fee:    (payment.amount * 100).to_i,
        body:         "Order #{payment.order_id}",
        notify_url:   CONFIG[:notify_url]
      }
    end

    def mock_payment_response(payment)
      {
        return_code:    "SUCCESS",
        result_code:    "SUCCESS",
        transaction_id: "WX_MOCK_#{SecureRandom.hex(8).upcase}",
        out_trade_no:   payment.idempotency_key,
        total_fee:      (payment.amount * 100).to_i,
        time_end:       Time.current.strftime("%Y%m%d%H%M%S")
      }
    end

    def mock_refund_response(refund)
      {
        return_code:      "SUCCESS",
        result_code:      "SUCCESS",
        refund_id:        "WXR_MOCK_#{SecureRandom.hex(8).upcase}",
        out_refund_no:    refund.idempotency_key,
        refund_fee:       (refund.amount * 100).to_i
      }
    end
  end
end
