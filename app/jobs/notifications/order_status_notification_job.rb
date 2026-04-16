# frozen_string_literal: true

# app/jobs/notifications/order_status_notification_job.rb
#
# 订单状态变更通知 Job
#
# 在订单状态流转后调用，向消费者或商家发送推送通知 + 站内通知。
#
# 使用方式：
#   Notifications::OrderStatusNotificationJob.perform_later(order_id: order.id, event: 'accepted')
#
# 支持的 event：
#   accepted       → 通知消费者「订单已被商家接受」
#   producing      → 通知消费者「商家开始制作」
#   delivered      → 通知消费者「订单已发货，请确认收货」
#   completed      → 通知商家「消费者已确认收货」
#   canceled       → 通知商家「订单已被取消」
#
module Notifications
  class OrderStatusNotificationJob < ApplicationJob
    queue_as :notifications

    EVENT_CONFIG = {
      'accepted'   => { recipient: :customer, title: '订单已接受',    body: '您的订单已被商家接受，正在准备制作', type: 'order_accepted' },
      'producing'  => { recipient: :customer, title: '订单制作中',    body: '商家已开始制作您的订单，请耐心等待', type: 'order_producing' },
      'delivered'  => { recipient: :customer, title: '订单已发货',    body: '您的订单已发货，请注意查收并确认收货', type: 'order_delivered' },
      'completed'  => { recipient: :merchant, title: '订单已完成',    body: '买家已确认收货，订单完成', type: 'order_completed' },
      'canceled'   => { recipient: :merchant, title: '订单已取消',    body: '该订单已被取消', type: 'order_canceled' }
    }.freeze

    def perform(order_id:, event:)
      order = Order.find_by(id: order_id)
      return unless order

      config = EVENT_CONFIG[event.to_s]
      return unless config

      recipient = order.public_send(config[:recipient])
      return unless recipient

      # 1. 异步推送到设备
      Notifications::SendPushNotificationJob.perform_later(
        user_id: recipient.id,
        title:   config[:title],
        body:    config[:body],
        data:    { order_id: order.id, type: config[:type] }
      )

      # 2. 写入站内通知
      recipient.notifications.create!(
        title:             config[:title],
        body:              config[:body],
        notification_type: config[:type],
        data:              { order_id: order.id }
      )

      # 3. 通过 ActionCable 实时广播订单状态变更
      ActionCable.server.broadcast(
        "order_status_#{order.id}",
        { order_id: order.id, status: order.status, event: event, updated_at: order.updated_at.iso8601 }
      )
    rescue StandardError => e
      Rails.logger.error("[OrderStatusNotificationJob] order=#{order_id} event=#{event} error=#{e.message}")
      raise # 让 Sidekiq 重试
    end
  end
end
