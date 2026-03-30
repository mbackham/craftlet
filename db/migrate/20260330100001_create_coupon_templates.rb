# frozen_string_literal: true

class CreateCouponTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :coupon_templates do |t|
      t.string  :name,            null: false,              comment: "模板名称"
      t.string  :coupon_type,     null: false,              comment: "类型: fixed_amount / discount / redeem_code"
      t.decimal :face_value,      precision: 12, scale: 2,  comment: "面值（满减：减少金额；折扣：折扣率 0-1；兑换码：商品价值）"
      t.decimal :min_order_amount,precision: 12, scale: 2, default: 0, comment: "最低使用金额，0 表示无限制"
      t.string  :status,         null: false, default: "draft", comment: "draft / active / inactive"

      # 使用限制
      t.jsonb   :category_ids,   null: false, default: [],  comment: "限制品类 ID 列表，空表示不限"
      t.jsonb   :merchant_ids,   null: false, default: [],  comment: "限制商家 ID 列表，空表示不限"
      t.datetime :valid_from,                               comment: "优惠券有效期开始时间"
      t.datetime :valid_until,                              comment: "优惠券有效期结束时间"
      t.integer  :valid_days,                               comment: "领取后 N 天内有效，与 valid_from/until 二选一"
      t.integer  :per_user_limit, default: 1,              comment: "每人最多领取张数，0 表示不限"

      # 发放规则
      t.jsonb   :grant_rules,    null: false, default: {},  comment: "发放规则: { new_user: true, birthday: true, min_level: 2 }"

      # 预算控制
      t.integer  :total_quota,                              comment: "总发放量，nil 表示不限"
      t.integer  :issued_count,  null: false, default: 0,  comment: "已发放数量"
      t.decimal  :budget_amount, precision: 14, scale: 2,  comment: "预算总额，nil 表示不限"
      t.decimal  :used_amount,   precision: 14, scale: 2, null: false, default: 0, comment: "已使用金额"
      t.decimal  :budget_alert_threshold, precision: 5, scale: 2, default: 0.8, comment: "预算告警阈值（比例），0.8 = 80%"

      t.text     :description,                              comment: "备注说明"
      t.timestamps
    end

    add_index :coupon_templates, :coupon_type
    add_index :coupon_templates, :status
  end
end
