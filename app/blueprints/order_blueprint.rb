# frozen_string_literal: true

# app/blueprints/order_blueprint.rb
#
# OrderBlueprint — Order 模型的 JSON 序列化器
#
# Views:
#   :default — 列表字段（状态、金额、客户摘要）
#   :detail  — 详情字段（含 order_items、payments、商家信息）
#
class OrderBlueprint < BaseBlueprint
  fields :order_no, :status, :currency, :cancel_reason

  field :total_amount do |order|
    order.total_amount.to_s
  end

  field :customer_nickname do |order|
    order.customer&.nickname
  end

  field :merchant_nickname do |order|
    order.merchant&.nickname
  end

  field :paid_at do |order|
    order.paid_at&.iso8601
  end

  field :created_at do |order|
    order.created_at&.iso8601
  end

  # ── 详情视图 ──────────────────────────────────────────────────────────────
  view :detail do
    association :order_items, blueprint: OrderItemBlueprint

    association :payments, blueprint: PaymentBlueprint

    field :accepted_at do |order|
      order.accepted_at&.iso8601
    end

    field :completed_at do |order|
      order.completed_at&.iso8601
    end

    field :canceled_at do |order|
      order.canceled_at&.iso8601
    end
  end
end
