# frozen_string_literal: true

# app/channels/order_status_channel.rb
#
# 订单状态实时推送 Channel
#
# 客户端订阅方式（JavaScript）：
#   const subscription = consumer.subscriptions.create(
#     { channel: 'OrderStatusChannel', order_id: 123 },
#     { received: (data) => console.log(data) }
#   )
#
# 广播示例（服务端）：
#   ActionCable.server.broadcast("order_status_#{order.id}", { status: 'accepted' })
#
class OrderStatusChannel < ApplicationCable::Channel
  def subscribed
    order_id = params[:order_id].to_i
    order    = Order.find_by(id: order_id)

    # 验证权限：只有该订单的消费者或商家可以订阅
    if order && authorized_for_order?(order)
      stream_from "order_status_#{order.id}"
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  private

  def authorized_for_order?(order)
    customer = Order.find_user_by_uuid(order.customer_id)
    merchant = Order.find_user_by_uuid(order.merchant_id)
    # ⚠️ Fix: 不能用 == 比较两次独立 DB 查询返回的不同 Ruby 对象实例
    # 必须比较 .id（Integer）才能正确判断是否为同一个用户
    current_user.id == customer&.id || current_user.id == merchant&.id
  end
end
