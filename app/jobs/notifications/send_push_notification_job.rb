# frozen_string_literal: true

# app/jobs/notifications/send_push_notification_job.rb
#
# 异步发送推送通知 Job
#
# 使用方式：
#   Notifications::SendPushNotificationJob.perform_later(
#     user_id: user.id,
#     title:   '标题',
#     body:    '正文',
#     data:    { order_id: 42, type: 'order_accepted' }
#   )
#
module Notifications
  class SendPushNotificationJob < ApplicationJob
    queue_as :notifications

    def perform(user_id:, title:, body:, data: {})
      user = User.find_by(id: user_id)
      return unless user

      Notifications::PushService.send_to_user(user, title: title, body: body, data: data)
    end
  end
end
