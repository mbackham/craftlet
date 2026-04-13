# frozen_string_literal: true

module Api
  module V1
    # MerchantsController — 商家状态 API
    # MerchantsController — Merchant status API
    #
    # Week 1 改造 / Week 1 refactor:
    #   - 改为继承 BaseController（接入 Logto JWT 认证）
    #   - 移除 before_action :authenticate_user!（由 BaseController 统一处理）
    #   - status_message 改用 I18n 翻译
    #
    #   - Now inherits BaseController (Logto JWT auth)
    #   - Removed before_action :authenticate_user! (handled by BaseController)
    #   - status_message now uses I18n translations
    class MerchantsController < BaseController
      # GET /api/v1/merchant/status
      # 返回当前用户的商家审核状态
      # Returns the current user's merchant review status
      def status
        merchant_profile = current_user.merchant_profile

        if merchant_profile.nil?
          render_success(data: {
            status:  'not_applied',
            message: I18n.t('api.merchants.status.not_applied')
          })
        else
          render_success(data: {
            status:          merchant_profile.status,
            shop_name:       merchant_profile.shop_name,
            message:         status_message(merchant_profile),
            rejected_reason: merchant_profile.reject_reason,
            approved_at:     merchant_profile.approved_at&.iso8601,
            rejected_at:     merchant_profile.rejected_at&.iso8601,
            created_at:      merchant_profile.created_at&.iso8601
          })
        end
      end

      private

      def status_message(profile)
        I18n.t("api.merchants.status.#{profile.status}", default: '')
      end
    end
  end
end
