class CreateAdminRolePermissions < ActiveRecord::Migration[7.1]
  def change
    create_table :admin_role_permissions do |t|
      t.references :admin_role, null: false, foreign_key: true
      t.references :admin_permission, null: false, foreign_key: true
      t.timestamps
    end

    add_index :admin_role_permissions, [:admin_role_id, :admin_permission_id], unique: true, name: 'index_admin_role_permissions_on_role_and_permission'
  end
end
