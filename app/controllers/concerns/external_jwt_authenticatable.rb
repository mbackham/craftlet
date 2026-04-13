# frozen_string_literal: true

# app/controllers/concerns/external_jwt_authenticatable.rb
#
# ExternalJwtAuthenticatable — Logto JWT 认证 Concern
# ExternalJwtAuthenticatable — Logto JWT authentication Concern
#
# 功能 / Features:
#   1. before_action :authenticate_from_logto! — 验证 Bearer token，注入 current_user
#   2. 自动同步用户（通过 Auth::UserSyncService）
#   3. 失败时返回标准 401 JSON 错误
#
#   1. before_action :authenticate_from_logto! — verifies Bearer token, injects current_user
#   2. Auto-syncs user via Auth::UserSyncService
#   3. Returns standard 401 JSON error on failure
#
# 用法 / Usage:
#   class Api::V1::BaseController < ActionController::API
#     include ExternalJwtAuthenticatable
#     before_action :authenticate_from_logto!
#   end
#
#   公开端点跳过 / Skip for public endpoints:
#     skip_before_action :authenticate_from_logto!
#
module ExternalJwtAuthenticatable
  extend ActiveSupport::Concern

  included do
    # current_user 可供所有子类访问 / current_user available to all subclasses
    attr_reader :current_user
  end

  # -----------------------------------------------------------------------
  # before_action：验证 JWT 并注入 current_user
  # before_action: verify JWT and inject current_user
  # -----------------------------------------------------------------------
  def authenticate_from_logto!
    # 如果 Logto 环境变量未配置，返回 503（服务尚不可用）
    # If Logto env vars are not configured, return 503 (service not yet available)
    unless Rails.application.config.try(:logto_configured)
      return render_error(
        message: 'Authentication service is not yet configured',
        code:    'auth_not_configured',
        status:  :service_unavailable
      )
    end

    token = extract_bearer_token
    unless token
      return render_unauthorized(
        message: I18n.t('api.errors.missing_token')
      )
    end

    claims = verify_token(token)
    unless claims
      return render_unauthorized(
        message: I18n.t('api.errors.invalid_token')
      )
    end

    user = sync_user(claims)
    unless user
      return render_unauthorized(
        message: I18n.t('api.errors.user_sync_failed')
      )
    end

    @current_user = user
  end

  # -----------------------------------------------------------------------
  # current_user? — 是否已认证的便捷判断
  # current_user? — convenience predicate
  # -----------------------------------------------------------------------
  def current_user?
    @current_user.present?
  end

  private

  # 从 Authorization 头提取 Bearer token
  # Extract Bearer token from Authorization header
  def extract_bearer_token
    header = request.headers['Authorization']
    return nil unless header&.start_with?('Bearer ')

    token = header.sub('Bearer ', '').strip
    token.presence
  end

  # 验证 token，返回 TokenClaims 或 nil（失败时记录日志）
  # Verify token, return TokenClaims or nil (logs on failure)
  def verify_token(token)
    Auth::JwtVerifier.call(token)
  rescue Auth::JwtVerifier::VerificationError => e
    Rails.logger.info("[ExternalJwtAuthenticatable] JWT verification failed: #{e.message}")
    nil
  rescue Auth::JwksFetcher::FetchError => e
    Rails.logger.error("[ExternalJwtAuthenticatable] JWKS fetch error: #{e.message}")
    nil
  end

  # 同步用户，返回 User 或 nil
  # Sync user, return User or nil
  def sync_user(claims)
    Auth::UserSyncService.call(claims)
  rescue => e
    Rails.logger.error("[ExternalJwtAuthenticatable] UserSync error: #{e.message}")
    nil
  end
end
