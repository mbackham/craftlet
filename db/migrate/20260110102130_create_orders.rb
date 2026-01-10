class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.string :order_no, null: false
      t.uuid :customer_id, null: false
      t.uuid :merchant_id, null: false
      t.string :status, null: false, default: "pending"
      t.decimal :total_amount, precision: 12, scale: 2, null: false
      t.string :currency, null: false, default: "CNY"
      t.string :cancel_reason
      t.string :canceled_by_type
      t.uuid :canceled_by_id
      t.datetime :paid_at
      t.datetime :accepted_at
      t.datetime :producing_at
      t.datetime :delivered_at
      t.datetime :completed_at
      t.datetime :canceled_at

      t.timestamps
    end

    add_index :orders, :order_no, unique: true
    add_index :orders, :customer_id
    add_index :orders, :merchant_id
    add_index :orders, :status
  end
end
