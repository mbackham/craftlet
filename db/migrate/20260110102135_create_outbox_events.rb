class CreateOutboxEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :outbox_events do |t|
      t.string :event_type, null: false
      t.string :aggregate_type, null: false
      t.uuid :aggregate_id, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.integer :retry_count, null: false, default: 0
      t.datetime :processed_at

      t.timestamps
    end

    add_index :outbox_events, [:aggregate_type, :aggregate_id]
    add_index :outbox_events, :event_type
    add_index :outbox_events, :status
  end
end
