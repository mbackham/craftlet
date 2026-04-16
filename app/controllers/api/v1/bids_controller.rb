# frozen_string_literal: true

# app/controllers/api/v1/bids_controller.rb
#
# GET  /api/v1/orders/:order_id/bids → 查看订单的所有报价
# POST /api/v1/orders/:order_id/bids → 商家提交报价
#
module Api
  module V1
    class BidsController < BaseController
      before_action :set_order

      # GET /api/v1/orders/:order_id/bids
      # 消费者（订单 customer）可以查看所有报价
      def index
        unless @order.customer_id == Order.id_to_uuid(current_user.id)
          return render_forbidden
        end

        render_success(data: BidBlueprint.render_as_hash(@order.bids))
      end

      # POST /api/v1/orders/:order_id/bids
      # 商家提交报价（bidder_id 为 UUID 编码格式）
      def create
        bid = @order.bids.new(
          bidder_id: Bid.id_to_uuid(current_user.id),
          amount: params[:amount],
          status: 'pending'
        )

        if bid.save
          render_success(data: BidBlueprint.render_as_hash(bid), status: :created)
        else
          render_validation_error(bid)
        end
      end

      private

      def set_order
        @order = Order.find(params[:order_id])
      end
    end
  end
end
