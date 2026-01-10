class CreateRefunds < ActiveRecord::Migration[7.1]
  def change
    create_table :refunds do |t|
      t.references :order, null: false, foreign_key: true
      t.references :payment, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :reason
      t.string :status, null: false, default: "init"
      t.string :provider_refund_no
      t.string :idempotency_key, null: false
      t.string :requested_by_type
      t.uuid :requested_by_id
      t.datetime :succeeded_at

      t.timestamps
    end

    add_index :refunds, :provider_refund_no, unique: true
    add_index :refunds, :idempotency_key, unique: true
    add_index :refunds, :status
  end
end
