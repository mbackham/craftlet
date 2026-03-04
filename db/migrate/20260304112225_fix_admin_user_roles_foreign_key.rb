class FixAdminUserRolesForeignKey < ActiveRecord::Migration[7.1]
  def up
    # 移除错误的指向 users 表的外键
    remove_foreign_key :admin_user_roles, :users if foreign_key_exists?(:admin_user_roles, :users)
    
    # 建立正确的指向 admin_users 表的外键
    add_foreign_key :admin_user_roles, :admin_users, column: :user_id
  end

  def down
    remove_foreign_key :admin_user_roles, :admin_users, column: :user_id if foreign_key_exists?(:admin_user_roles, column: :user_id)
    add_foreign_key :admin_user_roles, :users, column: :user_id
  end
end
