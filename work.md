目标
新增后台 RBAC 四张表：
admin_roles、admin_permissions、admin_user_roles、admin_role_permissions
新增审计表：audit_logs
在 User 里新增关联：admin_roles（不影响你原来的 roles）
seed 一套超级管理员权限（可重复执行）
云端 staging 可 db:migrate/db:seed


步骤1）生成 migrations + models
在项目根目录执行：

bundle exec rails g model AdminRole name:string code:string
bundle exec rails g model AdminPermission name:string code:string
bundle exec rails g model AdminUserRole user:references admin_role:references
bundle exec rails g model AdminRolePermission admin_role:references admin_permission:references

bundle exec rails g model AuditLog actor:references action:string target_type:string target_id:bigint before:jsonb after:jsonb request_id:string ip:string user_agent:string
2）修改 migration：加唯一索引（非常重要）
打开 db/migrate/*create_admin_roles*.rb：

class CreateAdminRoles < ActiveRecord::Migration[7.0]
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
db/migrate/*create_admin_permissions*.rb：

class CreateAdminPermissions < ActiveRecord::Migration[7.0]
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
db/migrate/*create_admin_user_roles*.rb（注意外键）：

class CreateAdminUserRoles < ActiveRecord::Migration[7.0]
  def change
    create_table :admin_user_roles do |t|
      t.references :user, null: false, foreign_key: true
      t.references :admin_role, null: false, foreign_key: true
      t.timestamps
    end

    add_index :admin_user_roles, [:user_id, :admin_role_id], unique: true
  end
end
db/migrate/*create_admin_role_permissions*.rb：

class CreateAdminRolePermissions < ActiveRecord::Migration[7.0]
  def change
    create_table :admin_role_permissions do |t|
      t.references :admin_role, null: false, foreign_key: true
      t.references :admin_permission, null: false, foreign_key: true
      t.timestamps
    end

    add_index :admin_role_permissions, [:admin_role_id, :admin_permission_id], unique: true
  end
end
db/migrate/*create_audit_logs*.rb（actor 指向 users）：

class CreateAuditLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :audit_logs do |t|
      t.references :actor, null: true, foreign_key: { to_table: :users }
      t.string :action, null: false

      t.string :target_type
      t.bigint :target_id

      t.jsonb :before
      t.jsonb :after

      t.string :request_id
      t.string :ip
      t.string :user_agent

      t.timestamps
    end

    add_index :audit_logs, [:target_type, :target_id]
    add_index :audit_logs, :action
    add_index :audit_logs, :created_at
  end
end
3）写 Model 关联（不会影响你现有 customer/merchant 体系）
3.1 在 app/models/user.rb 里新增这些关联
你现有的 has_many :roles 不动，只加下面这些（放在文件里合适位置即可）：

has_many :admin_user_roles, dependent: :destroy
has_many :admin_roles, through: :admin_user_roles

has_many :audit_logs, foreign_key: :actor_id, dependent: :nullify
并新增两个方法（不影响你现有 has_role?，名字不同）：

def admin_has_role?(code)
  admin_roles.where(code: code).exists?
end

def admin_can?(permission_code)
  AdminPermission.joins(admin_roles: :admin_user_roles)
                 .where(admin_user_roles: { user_id: id })
                 .where(code: permission_code)
                 .exists?
end
3.2 新增后台 RBAC 的 model 文件
app/models/admin_role.rb

class AdminRole < ApplicationRecord
  has_many :admin_user_roles, dependent: :destroy
  has_many :users, through: :admin_user_roles

  has_many :admin_role_permissions, dependent: :destroy
  has_many :admin_permissions, through: :admin_role_permissions
end
app/models/admin_permission.rb
class AdminPermission < ApplicationRecord
  has_many :admin_role_permissions, dependent: :destroy
  has_many :admin_roles, through: :admin_role_permissions
end
app/models/admin_user_role.rb

class AdminUserRole < ApplicationRecord
  belongs_to :user
  belongs_to :admin_role

  validates :user_id, uniqueness: { scope: :admin_role_id }
end
app/models/admin_role_permission.rb

class AdminRolePermission < ApplicationRecord
  belongs_to :admin_role
  belongs_to :admin_permission

  validates :admin_role_id, uniqueness: { scope: :admin_permission_id }
end
app/models/audit_log.rb
class AuditLog < ApplicationRecord
  belongs_to :actor, class_name: "User", optional: true
  validates :action, presence: true
end
4）跑迁移（本地）
bundle exec rails db:migrate
5）写 seeds（创建 super_admin + 权限，并可重复执行）
编辑 db/seeds.rb，加入：
admin_permissions = [
  { name: "后台访问", code: "admin.access" },
  { name: "后台用户查看", code: "admin.users.read" },
  { name: "后台角色管理", code: "admin.roles.manage" },
  { name: "后台权限查看", code: "admin.permissions.read" },
  { name: "后台审计查看", code: "admin.audit_logs.read" }
]

admin_permissions.each do |p|
  AdminPermission.find_or_create_by!(code: p[:code]) { |perm| perm.name = p[:name] }
end

super_admin_role = AdminRole.find_or_create_by!(code: "super_admin") { |r| r.name = "超级管理员" }

AdminPermission.find_each do |perm|
  AdminRolePermission.find_or_create_by!(admin_role: super_admin_role, admin_permission: perm)
end

puts "Admin RBAC seed done."
执行：bundle exec rails db:seed



