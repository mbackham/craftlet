# frozen_string_literal: true

module Api
  module V1
    module Merchants
      # ProfilesController — 商家端自我资料管理 API
      #
      # 路由：
      #   GET   /api/v1/merchant/profile → 查看自己的商家资料（含脱敏字段）
      #   PATCH /api/v1/merchant/profile → 更新可编辑字段
      class ProfilesController < BaseController
        before_action :require_merchant_profile!

        # GET /api/v1/merchant/profile
        def show
          render_success(data: MerchantProfileBlueprint.render_as_hash(@profile, view: :detail))
        end

        # PATCH /api/v1/merchant/profile
        # 只允许更新部分字段（审核通过后可更新联系信息）
        def update
          if @profile.update(profile_params)
            render_success(data: MerchantProfileBlueprint.render_as_hash(@profile, view: :detail))
          else
            render_validation_error(@profile)
          end
        end

        private

        def require_merchant_profile!
          @profile = current_user.merchant_profile
          render_not_found(message: '商家资料不存在，请先申请入驻') unless @profile
        end

        def profile_params
          params.require(:merchant).permit(
            :shop_name,
            :bank_name, :bank_branch,
            :address_province, :address_city, :address_district, :address_detail
          )
        end
      end
    end
  end
end
