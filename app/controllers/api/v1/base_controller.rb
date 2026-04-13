# frozen_string_literal: true

module Api
  module V1
    # BaseController — 所有 API v1 控制器的基类
    # BaseController — Base class for all API v1 controllers
    #
    # 包含 / Includes:
    #   ExternalJwtAuthenticatable — Logto JWT 认证
    #   ApiResponse                — 统一 JSON 响应格式
    #   LocaleSwitcher             — 请求级别的语言切换（继承自 ApplicationController 的逻辑提取）
    #
    #   ExternalJwtAuthenticatable — Logto JWT authentication
    #   ApiResponse                — Unified JSON response format
    #   LocaleSwitcher             — Per-request locale switching
    #
    # 默认：所有端点均需认证
    # Default: all endpoints require authentication
    # 公开端点使用：skip_before_action :authenticate_from_logto!
    # Public endpoints: skip_before_action :authenticate_from_logto!
    class BaseController < ActionController::API
      include ExternalJwtAuthenticatable
      include ApiResponse

      before_action :set_api_locale
      before_action :authenticate_from_logto!

      # 全局异常捕获 / Global exception rescue
      rescue_from ActionController::ParameterMissing do |e|
        render_error(message: e.message, code: 'parameter_missing', status: :bad_request)
      end

      rescue_from ActiveRecord::RecordNotFound do |_e|
        render_not_found
      end

      private

      # API 语言切换（无 session；优先级：params[:locale] > Accept-Language header > 默认中文）
      # API locale switching (no session; priority: params[:locale] > Accept-Language > default zh-CN)
      def set_api_locale
        requested = params[:locale].presence ||
                    extract_locale_from_accept_language_header
        locale_str = requested.to_s
        available  = I18n.available_locales.map(&:to_s)
        I18n.locale = available.include?(locale_str) ? locale_str.to_sym : I18n.default_locale
      end

      # 从 Accept-Language 头提取首选语言
      # Extract preferred locale from Accept-Language header
      def extract_locale_from_accept_language_header
        accept = request.env['HTTP_ACCEPT_LANGUAGE']
        return nil unless accept

        # "zh-CN,zh;q=0.9,en;q=0.8" → "zh-CN"
        accept.split(',').first&.split(';')&.first&.strip
      end
    end
  end
end
