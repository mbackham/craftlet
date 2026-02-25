# frozen_string_literal: true

module Payments
  # WeChat Pay provider.
  #
  # MOCK MODE: Active when WECHAT_MCH_ID is blank (no real credentials).
  # In mock mode all calls return synthetic data so the full pipeline can be
  # exercised without real credentials.
  #
  # ⚠️  STUB (Pending Business License):
  #   The `else` branches of create_payment / create_refund and the real
  #   verify_callback signature logic must be implemented once the merchant
  #   registration with WeChat Pay is complete.
  #
  # Real implementation guide (WeChat Pay API v3):
  #   - create_refund: POST /v3/refund/domestic/refunds
  #     * Sign request body with RSA-SHA256 using merchant private key
  #     * Header: Authorization: WECHATPAY2-SHA256-RSA2048 ...
  #   - verify_callback: Decrypt AES-256-GCM resource field; validate
  #     Wechatpay-Serial / Wechatpay-Signature header with HMAC-SHA256.
  class WechatProvider < BaseProvider
    CONFIG = Rails.application.config.payment_providers[:wechat]

    def create_payment(payment:)
      build_payment_request(payment) # build request struct (used in real mode)

      if mock_mode?
        Rails.logger.info("[WechatProvider] MOCK create_payment for payment##{payment.id}")
        raw = mock_payment_response(payment)
        ok_response(
          provider_trade_no: raw[:transaction_id],
          raw: raw
        )
      else
        # TODO: replace with real WeChat Pay JSAPI/Native call once license obtained
        # Example:
        #   WechatPay::V3::Order.create(params: build_payment_request(payment))
        err_response("WeChat Pay real integration not yet implemented — pending business license")
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
        # TODO: POST /v3/refund/domestic/refunds once license obtained
        # Required params:
        #   out_trade_no:  refund.payment.provider_trade_no
        #   out_refund_no: refund.idempotency_key   # idempotency key (unique per refund)
        #   amount.refund: (refund.amount * 100).to_i
        #   amount.total:  (refund.payment.amount * 100).to_i
        #   amount.currency: "CNY"
        # Sign with RSA-SHA256 merchant private key (API v3)
        err_response("WeChat Pay real refund integration not yet implemented — pending business license")
      end
    rescue => e
      Rails.logger.error("[WechatProvider] create_refund error: #{e.message}")
      err_response(e.message)
    end

    # Verifies the authenticity of an inbound WeChat Pay callback notification.
    #
    # MOCK MODE: always returns true.
    #
    # ⚠️  STUB — Real implementation (pending business license):
    #   1. Extract headers:
    #      - Wechatpay-Timestamp
    #      - Wechatpay-Nonce
    #      - Wechatpay-Signature
    #      - Wechatpay-Serial  (platform certificate serial)
    #   2. Build message string:
    #      "#{timestamp}\n#{nonce}\n#{raw_body}\n"
    #   3. Verify signature against WeChat platform public certificate
    #      using RSA-SHA256 (PKCS#1 v1.5).
    #   4. Decrypt payload.resource using AES-256-GCM with v3 API key.
    def verify_callback(headers:, payload:)
      return true if mock_mode?

      # TODO: implement RSA-SHA256 signature verification (WeChat Pay API v3)
      # Reference: https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay4_1.shtml
      Rails.logger.error("[WechatProvider] verify_callback: real signature verification not yet implemented")
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
        return_code:   "SUCCESS",
        result_code:   "SUCCESS",
        refund_id:     "WXR_MOCK_#{SecureRandom.hex(8).upcase}",
        out_refund_no: refund.idempotency_key,
        refund_fee:    (refund.amount * 100).to_i
      }
    end
  end
end
