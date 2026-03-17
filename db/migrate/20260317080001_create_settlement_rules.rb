# frozen_string_literal: true

class CreateSettlementRules < ActiveRecord::Migration[7.1]
  def change
    create_table :settlement_rules do |t|
      t.references :merchant_profile, null: true, foreign_key: true, comment: "关联商家（null=全局默认）"
      t.string     :cycle_type,              null: false, default: "T+7",  comment: "结算周期类型"
      t.integer    :cycle_days,              null: false, default: 7,      comment: "T+N 天数"
      t.decimal    :deposit_deduction_rate,  precision: 5, scale: 4, default: 0.0, null: false, comment: "保证金扣除比例"
      t.decimal    :penalty_rate,            precision: 5, scale: 4, default: 0.0, null: false, comment: "违约金比例"
      t.decimal    :min_settlement_amount,   precision: 12, scale: 2, default: 0.0, null: false, comment: "最低结算金额"
      t.boolean    :is_active,               default: true, null: false, comment: "是否启用"
      t.timestamps
    end

    add_index :settlement_rules, :is_active
    add_index :settlement_rules, [:merchant_profile_id, :is_active], name: "idx_settlement_rules_merchant_active"
  end
end
