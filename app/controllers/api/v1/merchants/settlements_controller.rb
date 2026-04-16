# frozen_string_literal: true

module Api
  module V1
    module Merchants
      # SettlementsController — 商家结算查询 API
      #
      # 路由：
      #   GET /api/v1/merchant/settlements      → 结算单列表
      #   GET /api/v1/merchant/settlements/:id  → 结算单详情
      class SettlementsController < BaseController
        include Pagy::Method
        before_action :require_merchant_profile!

        # GET /api/v1/merchant/settlements
        def index
          scope = @merchant_profile.settlements.order(created_at: :desc)
          pagy, settlements = pagy(scope)
          render_paginated(
            data: SettlementBlueprint.render_as_hash(settlements),
            pagy: pagy
          )
        end

        # GET /api/v1/merchant/settlements/:id
        def show
          settlement = @merchant_profile.settlements.find_by(id: params[:id])
          return render_not_found unless settlement

          render_success(data: SettlementBlueprint.render_as_hash(settlement, view: :detail))
        end

        private

        def require_merchant_profile!
          @merchant_profile = current_user.merchant_profile
          render_not_found(message: '商家资料不存在') unless @merchant_profile
        end
      end
    end
  end
end
