# frozen_string_literal: true

module Api
  module V1
    # MerchantsController — 商家状态 + 入驻申请 API
    #
    # GET  /api/v1/merchant/status → 查询入驻审核状态
    # POST /api/v1/merchant/apply  → 提交入驻申请（pending → submitted）
    class MerchantsController < BaseController
      # GET /api/v1/merchant/status
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

      # POST /api/v1/merchant/apply
      # 提交入驻申请，创建 MerchantProfile（status=submitted）
      # 同一用户只能申请一次（已有 profile 则报错）
      def apply
        if current_user.merchant_profile.present?
          return render_error(
            message: '您已提交过入驻申请，请勿重复提交',
            code:    'already_applied',
            status:  :unprocessable_entity
          )
        end

        profile = MerchantProfile.new(apply_params.merge(user: current_user, status: 'submitted'))

        if profile.save
          render_success(
            data:   MerchantProfileBlueprint.render_as_hash(profile),
            status: :created
          )
        else
          render_validation_error(profile)
        end
      end

      private

      def status_message(profile)
        I18n.t("api.merchants.status.#{profile.status}", default: '')
      end

      def apply_params
        params.require(:merchant).permit(
          :shop_name,
          :license_file_key,
          :idcard_front_key, :idcard_back_key,
          :bank_name, :bank_branch,
          :address_province, :address_city, :address_district, :address_detail
        )
      end
    end
  end
end
