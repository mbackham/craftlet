# frozen_string_literal: true

# app/controllers/api/v1/tickets_controller.rb
#
# 工单系统 API（消费者端）
#
# GET    /api/v1/tickets            → 工单列表（分页）
# POST   /api/v1/tickets            → 创建工单
# GET    /api/v1/tickets/:id        → 工单详情（含公开消息）
# POST   /api/v1/tickets/:id/messages → 追加消息
# PATCH  /api/v1/tickets/:id/close  → 关闭工单
#
# 注意：
#   - Ticket.creator_id 是 UUID 格式（UuidIdentity），无法使用 has_many 关联
#   - 所有查询通过 Ticket.id_to_uuid(current_user.id) 过滤
#   - 消费者只能看到自己创建的工单，只能看到 public_messages（internal: false）
#
module Api
  module V1
    class TicketsController < BaseController
      include Pagy::Method

      before_action :set_ticket, only: %i[show add_message close]

      # GET /api/v1/tickets
      def index
        tickets = Ticket.where(creator_id: Ticket.id_to_uuid(current_user.id))
                        .order(created_at: :desc)
        pagy, records = pagy(tickets)
        render_paginated(
          data: TicketBlueprint.render_as_hash(records),
          pagy: pagy
        )
      end

      # GET /api/v1/tickets/:id
      def show
        render_success(data: TicketBlueprint.render_as_hash(@ticket, view: :detail))
      end

      # POST /api/v1/tickets
      def create
        ticket = Ticket.new(ticket_params)
        ticket.creator_id   = Ticket.id_to_uuid(current_user.id)
        ticket.creator_type = 'User'

        if ticket.save
          # 异步发送「工单已提交」通知
          Notifications::TicketNotificationJob.perform_later(
            ticket_id: ticket.id,
            event: 'created'
          )
          render_success(data: TicketBlueprint.render_as_hash(ticket), status: :created)
        else
          render_validation_error(ticket)
        end
      end

      # POST /api/v1/tickets/:id/messages
      def add_message
        if @ticket.closed?
          return render_error(
            message: I18n.t('api.tickets.errors.closed_ticket'),
            code: 'ticket_closed',
            status: :unprocessable_entity
          )
        end

        message = @ticket.messages.build(
          content:     message_params[:content],
          sender_id:   TicketMessage.id_to_uuid(current_user.id),
          sender_type: 'User',
          internal:    false
        )

        if message.save
          # 通知：有新消息（通常是消费者回复，供管理员看；此处给消费者自己确认）
          render_success(data: TicketMessageBlueprint.render_as_hash(message), status: :created)
        else
          render_validation_error(message)
        end
      end

      # PATCH /api/v1/tickets/:id/close
      def close
        if @ticket.may_close?
          @ticket.close!
          render_success(data: TicketBlueprint.render_as_hash(@ticket))
        else
          render_error(
            message: I18n.t('api.tickets.errors.cannot_close'),
            code: 'invalid_state',
            status: :unprocessable_entity
          )
        end
      end

      private

      # 当前用户只能操作自己的工单（404 如果不属于该用户）
      def set_ticket
        @ticket = Ticket.find_by!(
          id:         params[:id],
          creator_id: Ticket.id_to_uuid(current_user.id)
        )
      rescue ActiveRecord::RecordNotFound
        render_not_found
      end

      def ticket_params
        params.require(:ticket).permit(:subject, :description, :category, :priority)
      end

      def message_params
        params.require(:message).permit(:content)
      end
    end
  end
end
