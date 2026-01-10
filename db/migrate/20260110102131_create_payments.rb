class CreatePayments < ActiveRecord::Migration[7.1]
  def change
    create_table :payments do |t|
      t.references :order, null: false, foreign_key: true
      t.string :channel, null: false
      t.string :status, null: false, default: "init"
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, null: false, default: "CNY"
      t.string :provider_trade_no
      t.string :idempotency_key, null: false
      t.datetime :paid_at

      t.timestamps
    end

    add_index :payments, :provider_trade_no, unique: true
    add_index :payments, :idempotency_key, unique: true
    add_index :payments, :status
  end
end
