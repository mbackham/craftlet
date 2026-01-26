class CreateAdminPermissions < ActiveRecord::Migration[7.1]
  def change
    create_table :admin_permissions do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.timestamps
    end

    add_index :admin_permissions, :code, unique: true
    add_index :admin_permissions, :name, unique: true
  end
end
