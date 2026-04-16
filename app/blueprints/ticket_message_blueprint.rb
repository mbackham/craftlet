# frozen_string_literal: true

# app/blueprints/ticket_message_blueprint.rb
#
# 工单消息序列化
#
class TicketMessageBlueprint < BaseBlueprint
  field :content do |msg|
    msg.content
  end

  field :sender_type do |msg|
    msg.sender_type
  end

  field :internal do |msg|
    msg.internal
  end

  field :created_at do |msg|
    msg.created_at&.iso8601
  end
end
