# frozen_string_literal: true

module Api
  module V1
    module Merchants
      # OrdersController — 商家端订单管理 API
      #
      # 路由前缀：/api/v1/merchant/orders
      #
      # 支持操作：
      #   GET    /api/v1/merchant/orders          → 商家待处理/历史订单列表
      #   GET    /api/v1/merchant/orders/:id      → 订单详情
      #   POST   /api/v1/merchant/orders/:id/accept          → 接单（paid → accepted）
      #   POST   /api/v1/merchant/orders/:id/start_producing → 开始制作（accepted → producing）
      #   POST   /api/v1/merchant/orders/:id/deliver         → 发货/完成服务（producing → delivered）
      class OrdersController < BaseController
        include Pagy::Method
        before_action :require_approved_merchant!
        before_action :set_merchant_order, only: %i[show accept start_producing deliver]

        # GET /api/v1/merchant/orders
        def index
          scope = current_user.merchant_orders
                              .includes(:order_items, :payments)
                              .order(created_at: :desc)

          # 状态过滤：?status=paid 等
          scope = scope.where(status: params[:status]) if params[:status].present?

          pagy, orders = pagy(scope)
          render_paginated(
            data:  OrderBlueprint.render_as_hash(orders, view: :merchant_list),
            pagy:  pagy
          )
        end

        # GET /api/v1/merchant/orders/:id
        def show
          render_success(data: OrderBlueprint.render_as_hash(@order, view: :merchant_detail))
        end

        # POST /api/v1/merchant/orders/:id/accept
        # paid → accepted（guard: merchant_active?）
        def accept
          if @order.may_accept?
            @order.accept!
            render_success(data: OrderBlueprint.render_as_hash(@order, view: :merchant_detail))
          else
            render_error(
              message: I18n.t('api.errors.order.cannot_accept', default: '当前订单状态不允许接单'),
              code:    'invalid_state',
              status:  :unprocessable_entity
            )
          end
        rescue AASM::InvalidTransition
          render_error(
            message: I18n.t('api.errors.order.cannot_accept', default: '当前订单状态不允许接单'),
            code:    'invalid_state',
            status:  :unprocessable_entity
          )
        end

        # POST /api/v1/merchant/orders/:id/start_producing
        # accepted → producing
        def start_producing
          if @order.may_start_producing?
            @order.start_producing!
            render_success(data: OrderBlueprint.render_as_hash(@order, view: :merchant_detail))
          else
            render_error(
              message: I18n.t('api.errors.order.invalid_state', default: '当前订单状态不允许此操作'),
              code:    'invalid_state',
              status:  :unprocessable_entity
            )
          end
        rescue AASM::InvalidTransition
          render_error(
            message: I18n.t('api.errors.order.invalid_state', default: '当前订单状态不允许此操作'),
            code:    'invalid_state',
            status:  :unprocessable_entity
          )
        end

        # POST /api/v1/merchant/orders/:id/deliver
        # producing → delivered
        def deliver
          if @order.may_deliver?
            @order.deliver!
            render_success(data: OrderBlueprint.render_as_hash(@order, view: :merchant_detail))
          else
            render_error(
              message: I18n.t('api.errors.order.invalid_state', default: '当前订单状态不允许此操作'),
              code:    'invalid_state',
              status:  :unprocessable_entity
            )
          end
        rescue AASM::InvalidTransition
          render_error(
            message: I18n.t('api.errors.order.invalid_state', default: '当前订单状态不允许此操作'),
            code:    'invalid_state',
            status:  :unprocessable_entity
          )
        end

        private

        def set_merchant_order
          @order = current_user.merchant_orders.find_by(id: params[:id])
          render_not_found unless @order
        end

        def require_approved_merchant!
          profile = current_user.merchant_profile
          return if profile&.approved?

          render_error(
            message: I18n.t('api.errors.merchant.not_approved', default: '需要已审核通过的商家账号'),
            code:    'merchant_not_approved',
            status:  :forbidden
          )
        end
      end
    end
  end
end
