# frozen_string_literal: true

class CreateCoupons < ActiveRecord::Migration[7.1]
  def change
    create_table :coupons do |t|
      t.references :coupon_template, null: false, foreign_key: true, comment: "关联的优惠券模板"
      t.bigint  :user_id,     null: false,                   comment: "持有用户 ID"
      t.string  :code,        null: false,                   comment: "优惠券码（兑换码类型用随机字符串）"
      t.string  :status,      null: false, default: "unused", comment: "unused / used / expired / locked"
      t.string  :grant_type,  null: false, default: "manual", comment: "发放来源: manual / new_user / birthday / level_up / redeem"
      t.datetime :granted_at, null: false,                   comment: "发放时间"
      t.datetime :expires_at,                                comment: "过期时间（由模板计算得出）"
      t.datetime :used_at,                                   comment: "使用时间"
      t.bigint  :order_id,                                   comment: "使用时关联的订单 ID"
      t.decimal :discount_amount, precision: 12, scale: 2,   comment: "实际抵扣金额"
      t.timestamps
    end

    add_index :coupons, :code, unique: true
    add_index :coupons, :user_id
    add_index :coupons, :status
    add_index :coupons, [:user_id, :coupon_template_id], name: "index_coupons_on_user_and_template"
    add_index :coupons, :order_id
  end
end
