# frozen_string_literal: true

# app/controllers/concerns/api_response.rb
#
# ApiResponse — 统一 API 响应格式 Concern
# ApiResponse — Unified API response format Concern
#
# 提供 render_success / render_error / render_paginated 三个帮助方法，
# 让所有 API 控制器返回一致的 JSON 结构。
#
# Provides render_success / render_error / render_paginated helpers
# so all API controllers return a consistent JSON structure.
#
# 成功响应格式 / Success response format:
#   { "success": true, "data": <payload>, "meta": <meta_optional> }
#
# 错误响应格式 / Error response format:
#   { "success": false, "error": { "code": "...", "message": "..." } }
#
module ApiResponse
  extend ActiveSupport::Concern

  # -------------------------------------------------------------------------
  # 成功响应 / Success responses
  # -------------------------------------------------------------------------

  # 普通成功 / Generic success
  # @param data   [Hash, Array, nil] 响应数据 / response payload
  # @param status [Symbol, Integer]  HTTP 状态码，默认 :ok / HTTP status, default :ok
  # @param meta   [Hash, nil]        可选元数据（分页等）/ optional metadata (pagination, etc.)
  def render_success(data: nil, status: :ok, meta: nil)
    body = { success: true, data: data }
    body[:meta] = meta if meta.present?
    render json: body, status: status
  end

  # 分页成功（与 Pagy 集成）
  # Paginated success (integrates with Pagy)
  # @param data        [Array]       当前页数据 / current page data
  # @param pagy        [Pagy]        Pagy 实例 / Pagy instance
  # @param status      [Symbol]      HTTP 状态码 / HTTP status
  def render_paginated(data:, pagy:, status: :ok)
    render_success(
      data:   data,
      status: status,
      meta:   {
        current_page:  pagy.page,
        total_pages:   pagy.pages,
        total_count:   pagy.count,
        per_page:      pagy.items
      }
    )
  end

  # -------------------------------------------------------------------------
  # 错误响应 / Error responses
  # -------------------------------------------------------------------------

  # 通用错误 / Generic error
  # @param message [String]          面向用户的错误信息 / user-facing error message
  # @param code    [String]          机器可读错误码 / machine-readable error code
  # @param status  [Symbol, Integer] HTTP 状态码 / HTTP status code
  def render_error(message:, code: 'error', status: :unprocessable_entity)
    render json: {
      success: false,
      error: {
        code:    code,
        message: message
      }
    }, status: status
  end

  # 401 Unauthorized
  def render_unauthorized(message: nil)
    render_error(
      message: message || I18n.t('api.errors.unauthorized'),
      code:    'unauthorized',
      status:  :unauthorized
    )
  end

  # 403 Forbidden
  def render_forbidden(message: nil)
    render_error(
      message: message || I18n.t('api.errors.forbidden'),
      code:    'forbidden',
      status:  :forbidden
    )
  end

  # 404 Not Found
  def render_not_found(message: nil)
    render_error(
      message: message || I18n.t('api.errors.not_found'),
      code:    'not_found',
      status:  :not_found
    )
  end

  # 422 Unprocessable Entity（含 ActiveRecord 校验错误）
  # 422 Unprocessable Entity (with ActiveRecord validation errors)
  def render_validation_error(record_or_message)
    message = if record_or_message.respond_to?(:errors)
                record_or_message.errors.full_messages.join('; ')
              else
                record_or_message.to_s
              end
    render_error(
      message: message,
      code:    'validation_error',
      status:  :unprocessable_entity
    )
  end

  # 500 Internal Server Error
  def render_server_error(message: nil)
    render_error(
      message: message || I18n.t('api.errors.server_error'),
      code:    'server_error',
      status:  :internal_server_error
    )
  end
end
