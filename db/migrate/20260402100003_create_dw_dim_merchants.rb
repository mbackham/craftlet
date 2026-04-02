class CreateDwDimMerchants < ActiveRecord::Migration[7.1]
  def change
    create_table :dw_dim_merchants do |t|
      t.bigint   :source_merchant_id, null: false
      t.bigint   :source_user_id
      t.string   :shop_name
      t.string   :status
      t.string   :province
      t.string   :city

      # Profile stats
      t.integer  :total_order_count, default: 0
      t.decimal  :total_gmv, precision: 14, scale: 2, default: 0
      t.decimal  :avg_order_amount, precision: 12, scale: 2, default: 0
      t.integer  :refund_count, default: 0
      t.decimal  :refund_rate, precision: 5, scale: 2, default: 0
      t.integer  :settlement_count, default: 0
      t.decimal  :total_settled_amount, precision: 14, scale: 2, default: 0
      t.integer  :risk_event_count, default: 0
      t.string   :merchant_tier, default: 'standard'
      t.decimal  :merchant_score, precision: 5, scale: 2, default: 0
      t.jsonb    :tags, default: []
      t.jsonb    :extra, default: {}

      t.datetime :profile_updated_at
      t.timestamps
    end

    add_index :dw_dim_merchants, :source_merchant_id, unique: true
    add_index :dw_dim_merchants, :merchant_tier
    add_index :dw_dim_merchants, :merchant_score
  end
end
