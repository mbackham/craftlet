class CreateOrderItems < ActiveRecord::Migration[7.1]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.string :item_type, null: false
      t.bigint :item_id, null: false
      t.string :name
      t.decimal :unit_price, precision: 10, scale: 2
      t.integer :quantity, default: 1
      t.decimal :subtotal, precision: 10, scale: 2

      t.timestamps
    end

    add_index :order_items, [:item_type, :item_id]
  end
end
