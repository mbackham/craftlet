# frozen_string_literal: true

# app/blueprints/order_blueprint.rb
#
# OrderBlueprint — Order 模型的 JSON 序列化器
#
# Views:
#   :default        — 列表字段（状态、金额、客户/商家摘要）
#   :detail         — 详情字段（含 order_items、payments、时间戳）
#   :merchant_list  — 商家端列表（含 customer_nickname，隐藏支付细节）
#   :merchant_detail — 商家端详情（含完整 order_items、阶段时间戳）
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

  # ── 商家端列表视图 ─────────────────────────────────────────────────────────
  view :merchant_list do
    field :producing_at do |order|
      order.producing_at&.iso8601
    end

    field :delivered_at do |order|
      order.delivered_at&.iso8601
    end
  end

  # ── 商家端详情视图 ─────────────────────────────────────────────────────────
  view :merchant_detail do
    association :order_items, blueprint: OrderItemBlueprint

    field :accepted_at do |order|
      order.accepted_at&.iso8601
    end

    field :producing_at do |order|
      order.producing_at&.iso8601
    end

    field :delivered_at do |order|
      order.delivered_at&.iso8601
    end

    field :completed_at do |order|
      order.completed_at&.iso8601
    end

    field :canceled_at do |order|
      order.canceled_at&.iso8601
    end
  end
end
