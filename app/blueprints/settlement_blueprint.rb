# frozen_string_literal: true

# SettlementBlueprint — 结算单序列化器
#
# Views:
#   :default — 结算单列表字段（金额摘要、周期、状态）
#   :detail  — 结算单详情（含明细金额拆分）
class SettlementBlueprint < BaseBlueprint
  fields :settlement_no, :status

  field :period_start do |s|
    s.period_start&.iso8601
  end

  field :period_end do |s|
    s.period_end&.iso8601
  end

  field :total_order_amount do |s|
    s.total_order_amount&.to_s
  end

  field :total_refund_amount do |s|
    s.total_refund_amount&.to_s
  end

  field :net_amount do |s|
    s.net_amount&.to_s
  end

  field :approved_at do |s|
    s.approved_at&.iso8601
  end

  field :paid_out_at do |s|
    s.paid_out_at&.iso8601
  end

  field :confirmed_at do |s|
    s.confirmed_at&.iso8601
  end

  field :created_at do |s|
    s.created_at&.iso8601
  end

  # ── 详情视图 ──────────────────────────────────────────────────────────────
  view :detail do
    field :deposit_deduction do |s|
      s.deposit_deduction&.to_s
    end

    field :penalty_amount do |s|
      s.penalty_amount&.to_s
    end

    field :payout_reference do |s|
      s.payout_reference
    end

    field :failure_reason do |s|
      s.failure_reason
    end

    field :frozen_reason do |s|
      s.frozen_reason
    end
  end
end
