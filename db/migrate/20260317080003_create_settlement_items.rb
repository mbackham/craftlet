# frozen_string_literal: true

class CreateSettlementItems < ActiveRecord::Migration[7.1]
  def change
    create_table :settlement_items do |t|
      t.references :settlement, null: false, foreign_key: true
      t.references :order,      null: false, foreign_key: true
      t.decimal    :order_amount,  precision: 12, scale: 2, null: false, default: 0.0
      t.decimal    :refund_amount, precision: 12, scale: 2, null: false, default: 0.0
      t.decimal    :net_amount,    precision: 12, scale: 2, null: false, default: 0.0
      t.timestamps
    end

    add_index :settlement_items, [:settlement_id, :order_id], unique: true,
              name: "idx_settlement_items_settlement_order"
  end
end
