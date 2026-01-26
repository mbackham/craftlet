class UpdateAuditLogsForAdmin < ActiveRecord::Migration[7.1]
  def change
    # Add new columns for admin audit logging
    add_column :audit_logs, :target_type, :string
    add_column :audit_logs, :target_id, :bigint
    add_column :audit_logs, :before, :jsonb
    add_column :audit_logs, :after, :jsonb
    add_column :audit_logs, :request_id, :string
    add_column :audit_logs, :ip, :string
    add_column :audit_logs, :user_agent, :string

    # Add indexes for better query performance
    add_index :audit_logs, [:target_type, :target_id]
    add_index :audit_logs, :created_at
  end
end
