# frozen_string_literal: true

# app/channels/notifications_channel.rb
#
# 站内通知实时推送 Channel
#
# 客户端订阅方式（JavaScript）：
#   const subscription = consumer.subscriptions.create(
#     { channel: 'NotificationsChannel' },
#     { received: (data) => console.log(data) }
#   )
#
# 广播示例（服务端）：
#   NotificationsChannel.broadcast_to(user, { title: '新消息', body: '...' })
#
class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    # 每个用户独占一个 stream，格式："notifications_user_{user_id}"
    stream_for current_user
  end

  def unsubscribed
    stop_all_streams
  end
end
