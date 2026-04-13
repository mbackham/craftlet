# frozen_string_literal: true

require 'openssl'

module Api
  module Webhooks
    # LogtoController — 处理 Logto Webhook 事件
    # LogtoController — Handles Logto webhook events
    #
    # 已支持的事件 / Supported events:
    #   User.Deleted       — 停用本地 User（软删除 / 清理 external_id）
    #   User.Data.Updated  — 同步用户信息变更
    #
    # 安全 / Security:
    #   HMAC-SHA256 签名验证（logto-signature-sha-256 header）
    #   HMAC-SHA256 signature verification (logto-signature-sha-256 header)
    #
    # 路由 / Route:
    #   POST /api/webhooks/logto
    #   （在 config/routes.rb 中定义）
    #
    class LogtoController < ActionController::API
      include ApiResponse

      # ⚠️  不需要 JWT 认证，用 HMAC 签名代替
      # ⚠️  No JWT auth — HMAC signature replaces it

      before_action :verify_webhook_signature

      # POST /api/webhooks/logto
      def receive
        event = params[:event].to_s
        Rails.logger.info("[LogtoWebhook] Received event: #{event}, hookId: #{params[:hookId]}")

        case event
        when 'User.Deleted'
          handle_user_deleted
        when 'User.Data.Updated'
          handle_user_data_updated
        else
          Rails.logger.debug("[LogtoWebhook] Unhandled event: #{event}")
        end

        render_success(data: { received: true })
      end

      private

      # -----------------------------------------------------------------------
      # HMAC-SHA256 签名验证
      # HMAC-SHA256 signature verification
      # -----------------------------------------------------------------------
      def verify_webhook_signature
        secret = ENV['LOGTO_WEBHOOK_SECRET']
        if secret.blank?
          Rails.logger.error('[LogtoWebhook] LOGTO_WEBHOOK_SECRET is not set')
          return render_error(
            message: 'Webhook not configured',
            code:    'webhook_misconfigured',
            status:  :internal_server_error
          )
        end

        received_sig = request.headers['logto-signature-sha-256'].to_s.strip
        if received_sig.blank?
          return render_error(
            message: 'Missing signature header',
            code:    'missing_signature',
            status:  :unauthorized
          )
        end

        body   = request.body.read
        request.body.rewind

        expected_sig = OpenSSL::HMAC.hexdigest('SHA256', secret, body)

        unless ActiveSupport::SecurityUtils.secure_compare(expected_sig, received_sig)
          Rails.logger.warn('[LogtoWebhook] Signature mismatch — possible spoofing attempt')
          return render_error(
            message: 'Invalid signature',
            code:    'invalid_signature',
            status:  :unauthorized
          )
        end
      end

      # -----------------------------------------------------------------------
      # 事件处理器 / Event handlers
      # -----------------------------------------------------------------------

      # Logto 用户被删除 → 停用本地记录
      # Logto user deleted → deactivate local record
      def handle_user_deleted
        logto_id = params.dig(:data, :id).to_s
        user     = User.find_by(external_id: logto_id)

        unless user
          Rails.logger.info("[LogtoWebhook] User.Deleted: no local user for logto_id=#{logto_id}")
          return
        end

        # 软停用：清空 external_id 防止后续 JWT 登录，标记 status
        # Soft-deactivate: clear external_id to block future JWT logins, mark status
        user.update!(
          external_id:  nil,
          status:       'deactivated'
        )
        Rails.logger.info("[LogtoWebhook] User.Deleted: deactivated user id=#{user.id}")
      end

      # Logto 用户信息更新 → 同步字段
      # Logto user data updated → sync fields
      def handle_user_data_updated
        logto_id = params.dig(:data, :id).to_s
        user     = User.find_by(external_id: logto_id)

        unless user
          Rails.logger.info("[LogtoWebhook] User.Data.Updated: no local user for logto_id=#{logto_id}")
          return
        end

        data  = params[:data] || {}
        attrs = {}
        attrs[:email]    = data[:primaryEmail].to_s.downcase.presence if data.key?(:primaryEmail)
        attrs[:phone]    = data[:primaryPhone].presence               if data.key?(:primaryPhone)
        attrs[:nickname] = data[:name].presence                       if data.key?(:name)

        if attrs.any?
          user.update!(attrs)
          Rails.logger.info("[LogtoWebhook] User.Data.Updated: updated user id=#{user.id}, fields=#{attrs.keys.join(', ')}")
        end
      end
    end
  end
end
