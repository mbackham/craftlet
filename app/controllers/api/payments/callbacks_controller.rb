# frozen_string_literal: true

module Api
  module Payments
    # Handles inbound payment provider callback (notify) requests.
    #
    # Routes:
    #   POST /api/payments/callbacks/wechat
    #   POST /api/payments/callbacks/alipay
    #
    # Security:
    #   - Signature verification is delegated to the provider's verify_callback method.
    #   - ⚠️  STUB: Real signature verification pending business license.
    #
    # Idempotency:
    #   - HandleCallbackService detects replay by provider_refund_no uniqueness.
    #   - Duplicate callbacks receive HTTP 200.
    class CallbacksController < ActionController::API
      # -----------------------------------------------------------------------
      # POST /api/payments/callbacks/wechat
      # -----------------------------------------------------------------------
      def wechat
        payload = parse_json_body
        provider = ::Payments::WechatProvider.new

        unless provider.verify_callback(headers: safe_headers, payload: payload)
          render json: { error: "Signature verification failed" }, status: :bad_request
          return
        end

        provider_refund_no = payload[:refund_id] || payload["refundId"]
        if provider_refund_no.blank?
          render json: { error: "Missing provider_refund_no" }, status: :bad_request
          return
        end

        # Inject Request IDs into the payload
        notify_payload = {
          raw_payload: payload,
          rails_request_id: request.request_id,
          third_party_request_id: payload["transaction_id"] || payload[:transaction_id],
          received_at: Time.current.iso8601
        }

        result = ::Payments::HandleCallbackService.new(
          channel:            "wechat",
          provider_refund_no: provider_refund_no,
          notify_payload:     notify_payload
        ).call

        if result.success?
          render json: { code: "SUCCESS", message: "OK" }, status: :ok
        else
          Rails.logger.error("[Callbacks#wechat] #{result.error}")
          render json: { error: result.error }, status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error("[Callbacks#wechat] Unexpected: #{e.class} #{e.message}")
        render json: { error: "Internal error" }, status: :internal_server_error
      end

      # -----------------------------------------------------------------------
      # POST /api/payments/callbacks/alipay
      # -----------------------------------------------------------------------
      def alipay
        payload = params.to_unsafe_h.except("controller", "action")
        provider = ::Payments::AlipayProvider.new

        unless provider.verify_callback(headers: safe_headers, payload: payload)
          render plain: "fail", status: :bad_request
          return
        end

        provider_refund_no = payload["out_request_no"]
        if provider_refund_no.blank?
          render plain: "fail", status: :bad_request
          return
        end

        # Inject Request IDs into the payload
        notify_payload = {
          raw_payload: payload.to_h,
          rails_request_id: request.request_id,
          third_party_request_id: payload["notify_id"] || payload["trade_no"],
          received_at: Time.current.iso8601
        }

        result = ::Payments::HandleCallbackService.new(
          channel:            "alipay",
          provider_refund_no: provider_refund_no,
          notify_payload:     notify_payload
        ).call

        if result.success?
          render plain: "success", status: :ok
        else
          Rails.logger.error("[Callbacks#alipay] #{result.error}")
          render plain: "fail", status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error("[Callbacks#alipay] Unexpected: #{e.class} #{e.message}")
        render plain: "fail", status: :internal_server_error
      end

      private

      def parse_json_body
        raw = request.body.read
        return {} if raw.blank?
        JSON.parse(raw).with_indifferent_access
      rescue JSON::ParserError
        {}
      end

      def safe_headers
        request.headers.env.select { |k, _| k.start_with?("HTTP_") }
      end
    end
  end
end
