class CreateEtlSyncLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :etl_sync_logs do |t|
      t.string   :source_table, null: false
      t.string   :target_table, null: false
      t.string   :sync_type, default: 'incremental'
      t.string   :status, default: 'running'
      t.integer  :extracted_count, default: 0
      t.integer  :loaded_count, default: 0
      t.integer  :cleaned_count, default: 0
      t.integer  :error_count, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.text     :error_message
      t.string   :batch_id, null: false
      t.jsonb    :metadata, default: {}
      t.timestamps
    end

    add_index :etl_sync_logs, :source_table
    add_index :etl_sync_logs, :status
    add_index :etl_sync_logs, :batch_id
    add_index :etl_sync_logs, :started_at
  end
end
