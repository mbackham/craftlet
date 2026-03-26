# frozen_string_literal: true

# === 内容管理权限 Seeds ===
# 运行: bin/rails runner db/seeds/content_permissions.rb

puts "Seeding content permissions..."

content_permissions = [
  { name: "查看内容", code: "content:read" },
  { name: "管理内容", code: "content:manage" }
]

content_permissions.each do |p|
  AdminPermission.find_or_create_by!(code: p[:code]) { |perm| perm.name = p[:name] }
end

# 将内容权限添加到超级管理员角色
super_admin_role = AdminRole.find_by(code: "super_admin")
if super_admin_role
  AdminPermission.find_each do |perm|
    AdminRolePermission.find_or_create_by!(admin_role: super_admin_role, admin_permission: perm)
  end
end

# 将内容权限添加到运营角色
ops_role = AdminRole.find_by(code: "ops")
if ops_role
  content_permissions.each do |p|
    perm = AdminPermission.find_by(code: p[:code])
    AdminRolePermission.find_or_create_by!(admin_role: ops_role, admin_permission: perm) if perm
  end
end

puts "Content permissions seed done."
