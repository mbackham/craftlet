class CreatePaymentCallbacks < ActiveRecord::Migration[7.1]
  def change
    create_table :payment_callbacks do |t|
      t.references :payment, null: false, foreign_key: true
      t.string :channel, null: false
      t.string :provider_trade_no, null: false
      t.jsonb :headers, null: false, default: {}
      t.jsonb :payload, null: false, default: {}
      t.boolean :verified, null: false, default: false
      t.string :process_status, null: false, default: "pending"
      t.text :process_error
      t.datetime :received_at

      t.timestamps
    end

    add_index :payment_callbacks, [:channel, :provider_trade_no]
    add_index :payment_callbacks, :process_status
  end
end
