class CreateReconciliationBatches < ActiveRecord::Migration[7.1]
  def change
    create_table :reconciliation_batches do |t|
      t.date :target_date
      t.string :status
      t.string :channel
      t.integer :total_count, default: 0
      t.integer :matched_count, default: 0
      t.integer :mismatched_count, default: 0

      t.timestamps
    end
  end
end
