# frozen_string_literal: true

# app/controllers/api/v1/orders_controller.rb
#
# 消费者端订单 API
#
# GET    /api/v1/orders          → 订单列表（分页）
# GET    /api/v1/orders/:id      → 订单详情
# POST   /api/v1/orders          → 创建订单
# POST   /api/v1/orders/:id/cancel → 取消订单
#
module Api
  module V1
    class OrdersController < BaseController
      include Pagy::Method

      before_action :set_order, only: [:show, :cancel]

      # GET /api/v1/orders
      def index
        orders = current_user.customer_orders
                             .includes(:order_items, :payments)
                             .order(created_at: :desc)
        pagy, records = pagy(orders)
        render_paginated(
          data: OrderBlueprint.render_as_hash(records),
          pagy: pagy
        )
      end

      # GET /api/v1/orders/:id
      def show
        unless owns_order?(@order)
          return render_forbidden
        end

        render_success(data: OrderBlueprint.render_as_hash(@order, view: :detail))
      end

      # POST /api/v1/orders
      def create
        order = Order.new(order_params)
        order.customer_id = Order.id_to_uuid(current_user.id)
        order.order_no    = generate_order_no
        order.status      = 'created'   # AASM 初始状态（DB default 为 pending，需显式设置）

        if order.save
          render_success(data: OrderBlueprint.render_as_hash(order, view: :detail), status: :created)
        else
          render_validation_error(order)
        end
      end

      # POST /api/v1/orders/:id/cancel
      def cancel
        unless owns_order_as_customer?(@order)
          return render_forbidden
        end

        unless @order.may_cancel?
          return render_error(
            message: I18n.t('api.errors.order.cannot_cancel'),
            code: 'invalid_state',
            status: :unprocessable_entity
          )
        end

        @order.cancel!
        render_success(data: OrderBlueprint.render_as_hash(@order))
      rescue AASM::InvalidTransition
        render_error(
          message: I18n.t('api.errors.order.cannot_cancel'),
          code: 'invalid_state',
          status: :unprocessable_entity
        )
      end

      private

      def set_order
        @order = Order.find(params[:id])
      end

      def order_params
        params.require(:order).permit(
          :merchant_id, :total_amount, :currency, :cancel_reason
        )
      end

      def generate_order_no
        "ORD#{Time.current.strftime('%Y%m%d%H%M%S')}#{SecureRandom.hex(3).upcase}"
      end

      def owns_order?(order)
        owns_order_as_customer?(order) || owns_order_as_merchant?(order)
      end

      def owns_order_as_customer?(order)
        order.customer_id == Order.id_to_uuid(current_user.id)
      end

      def owns_order_as_merchant?(order)
        order.merchant_id == Order.id_to_uuid(current_user.id)
      end
    end
  end
end
