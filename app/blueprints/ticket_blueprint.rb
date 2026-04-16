# frozen_string_literal: true

# app/blueprints/ticket_blueprint.rb
#
# 工单序列化
# ─ 默认视图：列表所需字段（ticket_no, subject, status, category, priority, timestamps）
# ─ :detail 视图：追加 description, messages 关联
#
class TicketBlueprint < BaseBlueprint
  fields :ticket_no, :subject, :status, :category, :priority

  field :created_at do |ticket|
    ticket.created_at&.iso8601
  end

  field :assigned_at do |ticket|
    ticket.assigned_at&.iso8601
  end

  field :resolved_at do |ticket|
    ticket.resolved_at&.iso8601
  end

  field :closed_at do |ticket|
    ticket.closed_at&.iso8601
  end

  view :detail do
    field :description do |ticket|
      ticket.description
    end

    association :messages, blueprint: TicketMessageBlueprint, name: :messages do |ticket|
      ticket.messages.public_messages.order(:created_at)
    end
  end
end
