class CreateDwDimUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :dw_dim_users do |t|
      t.bigint   :source_user_id, null: false
      t.string   :email
      t.string   :phone
      t.string   :nickname
      t.string   :status
      t.string   :user_level, default: 'normal'
      t.string   :registration_channel

      # Profile stats
      t.integer  :total_order_count, default: 0
      t.decimal  :total_order_amount, precision: 14, scale: 2, default: 0
      t.decimal  :avg_order_amount, precision: 12, scale: 2, default: 0
      t.integer  :refund_count, default: 0
      t.decimal  :refund_rate, precision: 5, scale: 2, default: 0
      t.integer  :coupon_used_count, default: 0
      t.decimal  :coupon_total_discount, precision: 12, scale: 2, default: 0
      t.datetime :first_order_at
      t.datetime :last_order_at
      t.integer  :days_since_last_order
      t.string   :rfm_segment
      t.jsonb    :tags, default: []
      t.jsonb    :extra, default: {}

      t.datetime :profile_updated_at
      t.timestamps
    end

    add_index :dw_dim_users, :source_user_id, unique: true
    add_index :dw_dim_users, :rfm_segment
    add_index :dw_dim_users, :user_level
  end
end
