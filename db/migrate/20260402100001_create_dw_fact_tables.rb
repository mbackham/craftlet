class CreateDwFactTables < ActiveRecord::Migration[7.1]
  def change
    create_table :dw_fact_orders do |t|
      t.bigint   :source_id, null: false
      t.string   :order_no
      t.string   :customer_id
      t.string   :merchant_id
      t.string   :status
      t.decimal  :total_amount, precision: 12, scale: 2
      t.string   :currency
      t.datetime :paid_at
      t.datetime :completed_at
      t.datetime :canceled_at
      t.bigint   :dim_time_id
      t.datetime :synced_at
      t.string   :etl_batch_id
      t.timestamps
    end
    add_index :dw_fact_orders, :source_id, unique: true
    add_index :dw_fact_orders, :status
    add_index :dw_fact_orders, :paid_at
    add_index :dw_fact_orders, :etl_batch_id

    create_table :dw_fact_payments do |t|
      t.bigint   :source_id, null: false
      t.bigint   :order_source_id
      t.string   :channel
      t.decimal  :amount, precision: 12, scale: 2
      t.string   :status
      t.datetime :paid_at
      t.datetime :synced_at
      t.string   :etl_batch_id
      t.timestamps
    end
    add_index :dw_fact_payments, :source_id, unique: true
    add_index :dw_fact_payments, :order_source_id
    add_index :dw_fact_payments, :etl_batch_id

    create_table :dw_fact_refunds do |t|
      t.bigint   :source_id, null: false
      t.bigint   :order_source_id
      t.decimal  :amount, precision: 12, scale: 2
      t.string   :reason
      t.string   :status
      t.datetime :succeeded_at
      t.datetime :synced_at
      t.string   :etl_batch_id
      t.timestamps
    end
    add_index :dw_fact_refunds, :source_id, unique: true
    add_index :dw_fact_refunds, :order_source_id
    add_index :dw_fact_refunds, :etl_batch_id

    create_table :dw_fact_settlements do |t|
      t.bigint   :source_id, null: false
      t.bigint   :merchant_source_id
      t.decimal  :net_amount, precision: 12, scale: 2
      t.string   :status
      t.date     :period_start
      t.date     :period_end
      t.datetime :synced_at
      t.string   :etl_batch_id
      t.timestamps
    end
    add_index :dw_fact_settlements, :source_id, unique: true
    add_index :dw_fact_settlements, :merchant_source_id
    add_index :dw_fact_settlements, :etl_batch_id

    create_table :dw_fact_coupons do |t|
      t.bigint   :source_id, null: false
      t.bigint   :user_id
      t.bigint   :template_id
      t.decimal  :discount_amount, precision: 12, scale: 2
      t.datetime :used_at
      t.datetime :synced_at
      t.string   :etl_batch_id
      t.timestamps
    end
    add_index :dw_fact_coupons, :source_id, unique: true
    add_index :dw_fact_coupons, :user_id
    add_index :dw_fact_coupons, :etl_batch_id
  end
end
