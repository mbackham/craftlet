class CreateAuditLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :audit_logs do |t|
      t.string :actor_type, null: false
      t.uuid :actor_id, null: false
      t.string :action, null: false
      t.string :subject_type, null: false
      t.uuid :subject_id, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :audit_logs, [:actor_type, :actor_id]
    add_index :audit_logs, [:subject_type, :subject_id]
    add_index :audit_logs, :action
  end
end
