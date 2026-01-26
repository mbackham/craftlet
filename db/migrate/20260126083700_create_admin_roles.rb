class CreateAdminRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :admin_roles do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.timestamps
    end

    add_index :admin_roles, :code, unique: true
    add_index :admin_roles, :name, unique: true
  end
end
