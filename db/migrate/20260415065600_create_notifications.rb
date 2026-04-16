class CreateNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications do |t|
      t.bigint :user_id, null: false
      t.string :title, null: false
      t.text :body
      t.string :notification_type, null: false, comment: 'order_accepted / order_rejected / bid_received / system'
      t.datetime :read_at
      t.jsonb :data, default: {}

      t.timestamps
    end

    add_index :notifications, :user_id
    add_index :notifications, [:user_id, :read_at]
    add_index :notifications, :notification_type
  end
end
