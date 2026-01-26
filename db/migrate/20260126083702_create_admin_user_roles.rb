class CreateAdminUserRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :admin_user_roles do |t|
      t.references :user, null: false, foreign_key: true
      t.references :admin_role, null: false, foreign_key: true
      t.timestamps
    end

    add_index :admin_user_roles, [:user_id, :admin_role_id], unique: true
  end
end
