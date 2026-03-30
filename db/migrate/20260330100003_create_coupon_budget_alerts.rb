# frozen_string_literal: true

class CreateCouponBudgetAlerts < ActiveRecord::Migration[7.1]
  def change
    create_table :coupon_budget_alerts do |t|
      t.references :coupon_template, null: false, foreign_key: true, comment: "关联模板"
      t.string  :alert_type,   null: false, comment: "quota_threshold / budget_threshold / quota_exhausted / budget_exhausted"
      t.decimal :current_ratio, precision: 5, scale: 4, comment: "触发时的使用比例"
      t.string  :status,       null: false, default: "pending", comment: "pending / acknowledged"
      t.bigint  :acknowledged_by_id,                           comment: "处理人 AdminUser ID"
      t.datetime :acknowledged_at,                             comment: "处理时间"
      t.timestamps
    end

    add_index :coupon_budget_alerts, :status
    add_index :coupon_budget_alerts, :alert_type
  end
end
