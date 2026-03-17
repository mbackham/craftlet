# frozen_string_literal: true

class CreateSettlements < ActiveRecord::Migration[7.1]
  def change
    create_table :settlements do |t|
      t.string     :settlement_no,       null: false,  comment: "结算单号"
      t.references :merchant_profile,    null: false, foreign_key: true, comment: "关联商家"
      t.date       :period_start,        null: false,  comment: "结算周期起始"
      t.date       :period_end,          null: false,  comment: "结算周期结束"
      t.decimal    :total_order_amount,  precision: 12, scale: 2, default: 0.0, null: false
      t.decimal    :total_refund_amount, precision: 12, scale: 2, default: 0.0, null: false
      t.decimal    :deposit_deduction,   precision: 12, scale: 2, default: 0.0, null: false
      t.decimal    :penalty_amount,      precision: 12, scale: 2, default: 0.0, null: false
      t.decimal    :net_amount,          precision: 12, scale: 2, default: 0.0, null: false, comment: "实际结算金额"
      t.string     :status,             null: false, default: "pending_review", comment: "状态"
      t.bigint     :approved_by,        comment: "审批人 admin_user_id"
      t.datetime   :approved_at
      t.bigint     :paid_out_by,        comment: "出纳 admin_user_id"
      t.datetime   :paid_out_at
      t.datetime   :confirmed_at,       comment: "到账确认时间"
      t.string     :payout_reference,   comment: "打款凭证号"
      t.string     :failure_reason,     limit: 500
      t.string     :frozen_reason,      limit: 500
      t.timestamps
    end

    add_index :settlements, :settlement_no, unique: true
    add_index :settlements, :status
    add_index :settlements, [:merchant_profile_id, :period_start, :period_end],
              name: "idx_settlements_merchant_period", unique: true
  end
end
