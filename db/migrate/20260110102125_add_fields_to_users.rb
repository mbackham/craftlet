class AddFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :phone, :string
    add_column :users, :nickname, :string
    add_column :users, :avatar_key, :string
    add_column :users, :status, :string, null: false, default: "active"
    add_column :users, :disabled_at, :datetime
    add_column :users, :disabled_reason, :string

    add_index :users, :phone, unique: true
    add_index :users, :status
    add_index :users, :disabled_at
  end
end
