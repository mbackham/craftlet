# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
# Create default admin user in development
if Rails.env.development?
  AdminUser.find_or_create_by!(email: 'admin@example.com') do |admin|
    admin.password = 'password'
    admin.password_confirmation = 'password'
  end
end

# Admin RBAC Seeds
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

# Assign super_admin role to default admin user
if Rails.env.development?
  admin_user = AdminUser.find_by(email: 'admin@example.com')
  if admin_user
    AdminUserRole.find_or_create_by!(user: admin_user, admin_role: super_admin_role)
  end
end

puts "Admin RBAC seed done."