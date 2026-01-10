class CreateRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :roles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :role_type, null: false
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end

    add_index :roles, [:user_id, :role_type], unique: true
    add_index :roles, :role_type
    add_index :roles, :is_active
  end
end
