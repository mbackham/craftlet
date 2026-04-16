# frozen_string_literal: true

# app/services/notifications/push_service.rb
#
# Expo Push Notifications 推送服务
#
# 使用方式：
#   Notifications::PushService.send_to_user(user, title: '标题', body: '内容', data: {})
#
# 依赖：
#   gem 'exponent-server-sdk'（Week 4 新增）
#
module Notifications
  class PushService
    # 向指定用户的所有设备发送推送通知
    #
    # @param user [User] 目标用户
    # @param title [String] 通知标题
    # @param body [String] 通知正文
    # @param data [Hash] 附带数据（供 App 端路由跳转使用）
    def self.send_to_user(user, title:, body:, data: {})
      tokens = user.device_tokens.pluck(:token)
      return if tokens.empty?

      client = Exponent::Push::Client.new
      messages = tokens.map do |token|
        {
          to:    token,
          title: title,
          body:  body,
          data:  data,
          sound: 'default'
        }
      end

      client.publish(messages)
    rescue StandardError => e
      Rails.logger.error("[Notifications::PushService] Push failed for user=#{user.id}: #{e.message}")
      Sentry.capture_exception(e) if defined?(Sentry)
    end

    # 批量推送（多用户）
    #
    # @param users [ActiveRecord::Relation, Array<User>] 目标用户列表
    # @param title [String]
    # @param body [String]
    # @param data [Hash]
    def self.broadcast_to_users(users, title:, body:, data: {})
      users.each do |user|
        send_to_user(user, title: title, body: body, data: data)
      end
    end
  end
end
