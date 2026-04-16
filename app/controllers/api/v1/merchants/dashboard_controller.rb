# frozen_string_literal: true

module Api
  module V1
    module Merchants
      # DashboardController — 商家数据看板 API
      #
      # 路由：GET /api/v1/merchant/dashboard
      class DashboardController < BaseController
        before_action :require_approved_merchant!

        # GET /api/v1/merchant/dashboard
        def show
          orders = current_user.merchant_orders

          render_success(data: {
            # 今日订单（按 created_at 日期）
            today_orders_count:    orders.where(created_at: Time.current.all_day).count,
            # 待接单（paid 状态）
            pending_accept_count:  orders.where(status: 'paid').count,
            # 制作中
            producing_count:       orders.where(status: 'producing').count,
            # 待发货（producing 之后）
            delivering_count:      orders.where(status: 'delivered').count,
            # 本月已完成
            this_month_completed:  orders.where(status: 'completed')
                                         .where(completed_at: Time.current.all_month)
                                         .count,
            # 本月营业额（completed 状态，按 completed_at）
            this_month_revenue:    orders.where(status: 'completed')
                                         .where(completed_at: Time.current.all_month)
                                         .sum(:total_amount)
                                         .to_s,
            # 累计完成订单数
            total_completed_count: orders.where(status: 'completed').count,
            # 商家状态
            merchant_status:       current_user.merchant_profile&.status
          })
        end

        private

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
