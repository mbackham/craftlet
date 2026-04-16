# frozen_string_literal: true

# app/jobs/notifications/ticket_notification_job.rb
#
# 工单状态/消息通知 Job
#
# 使用方式：
#   Notifications::TicketNotificationJob.perform_later(ticket_id: ticket.id, event: 'new_message')
#
module Notifications
  class TicketNotificationJob < ApplicationJob
    queue_as :notifications

    EVENT_CONFIG = {
      'created'     => { title: '工单已提交',   body: '您的工单已提交，客服将尽快处理',     type: 'ticket_created' },
      'assigned'    => { title: '工单已分配',   body: '您的工单已分配给客服处理',             type: 'ticket_assigned' },
      'resolved'    => { title: '工单已解决',   body: '您的工单已被标记为解决，如有问题可重新开启', type: 'ticket_resolved' },
      'new_message' => { title: '工单新回复',   body: '您的工单有新的客服回复，请查看',         type: 'ticket_message' }
    }.freeze

    def perform(ticket_id:, event:)
      ticket = Ticket.find_by(id: ticket_id)
      return unless ticket

      config = EVENT_CONFIG[event.to_s]
      return unless config

      # 通知工单创建者
      creator = ticket.creator
      return unless creator.is_a?(User)

      Notifications::SendPushNotificationJob.perform_later(
        user_id: creator.id,
        title:   config[:title],
        body:    config[:body],
        data:    { ticket_id: ticket.id, ticket_no: ticket.ticket_no, type: config[:type] }
      )

      creator.notifications.create!(
        title:             config[:title],
        body:              config[:body],
        notification_type: config[:type],
        data:              { ticket_id: ticket.id, ticket_no: ticket.ticket_no }
      )
    rescue StandardError => e
      Rails.logger.error("[TicketNotificationJob] ticket=#{ticket_id} event=#{event} error=#{e.message}")
      raise
    end
  end
end
