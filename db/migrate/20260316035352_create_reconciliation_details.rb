class CreateReconciliationDetails < ActiveRecord::Migration[7.1]
  def change
    create_table :reconciliation_details do |t|
      t.references :reconciliation_batch, null: false, foreign_key: true
      t.string :transaction_no
      t.string :order_no
      t.string :reconciliation_type
      t.decimal :system_amount, precision: 10, scale: 2
      t.decimal :statement_amount, precision: 10, scale: 2
      t.string :match_status
      t.string :process_status
      t.integer :handler_admin_id
      t.text :adjustment_reason
      t.text :error_message

      t.timestamps
    end

    add_index :reconciliation_details, :transaction_no
    add_index :reconciliation_details, :order_no
  end
end
