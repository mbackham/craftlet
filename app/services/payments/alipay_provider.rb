# frozen_string_literal: true

module Payments
  # Alipay provider.
  #
  # MOCK MODE: Active when ALIPAY_APP_ID is blank (no real credentials).
  # In mock mode all calls return synthetic data so the full pipeline can be
  # exercised without real credentials.
  #
  # ⚠️  STUB (Pending Business License):
  #   The `else` branches and the real verify_callback RSA2 logic must be
  #   implemented once the Alipay merchant registration is complete.
  #
  # Real implementation guide (Alipay Open API):
  #   - create_refund: alipay.trade.refund
  #     * Sign request using RSA2 (SHA256WithRSA) with merchant private key
  #     * out_request_no must be unique per refund (use idempotency_key)
  #   - verify_callback: validate sign field in POST params using
  #     Alipay public key RSA2 signature verification.
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
        # TODO: call alipay.trade.page.pay or alipay.trade.app.pay once license obtained
        err_response("Alipay real integration not yet implemented — pending business license")
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
        # TODO: call alipay.trade.refund once license obtained
        # Required params:
        #   trade_no:       refund.payment.provider_trade_no
        #   out_request_no: refund.idempotency_key  # idempotency key (unique per refund)
        #   refund_amount:  refund.amount.to_s
        #   refund_reason:  refund.reason
        # Sign with RSA2 (SHA256WithRSA) using merchant app private key
        err_response("Alipay real refund integration not yet implemented — pending business license")
      end
    rescue => e
      Rails.logger.error("[AlipayProvider] create_refund error: #{e.message}")
      err_response(e.message)
    end

    # Verifies the authenticity of an inbound Alipay callback notification.
    #
    # MOCK MODE: always returns true.
    #
    # ⚠️  STUB — Real implementation (pending business license):
    #   1. Extract POST params (application/x-www-form-urlencoded)
    #   2. Sort all params except `sign` and `sign_type` alphabetically
    #   3. Concatenate as "key=value&key=value..."
    #   4. Verify `sign` parameter using Alipay public key with RSA2
    #      (SHA256WithRSA / PKCS#1 v1.5)
    #   Reference: https://opendocs.alipay.com/open/270/105902
    def verify_callback(headers:, payload:)
      return true if mock_mode?

      # TODO: implement RSA2 signature verification via alipay gem
      # Example: Alipay::Utils::Crypt.rsa2_verify(content, sign, alipay_public_key)
      Rails.logger.error("[AlipayProvider] verify_callback: real RSA2 signature verification not yet implemented")
      false
    end

    private

    def mock_mode?
      CONFIG[:app_id].blank?
    end

    def mock_payment_response(payment)
      {
        code:         "10000",
        msg:          "Success",
        trade_no:     "ALI_MOCK_#{SecureRandom.hex(8).upcase}",
        out_trade_no: payment.idempotency_key,
        total_amount: payment.amount.to_s,
        gmt_payment:  Time.current.strftime("%Y-%m-%d %H:%M:%S")
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
