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

# === 商家管理权限 ===
merchant_permissions = [
  { name: "查看商家", code: "merchant:read" },
  { name: "审批商家", code: "merchant:approve" }
]

merchant_permissions.each do |p|
  AdminPermission.find_or_create_by!(code: p[:code]) { |perm| perm.name = p[:name] }
end

# 将商家权限添加到超级管理员角色
merchant_permissions.each do |p|
  perm = AdminPermission.find_by(code: p[:code])
  AdminRolePermission.find_or_create_by!(admin_role: super_admin_role, admin_permission: perm) if perm
end

puts "Merchant permissions seed done."

# === 商家测试数据 (仅开发环境) ===
if Rails.env.development?
  # 创建测试用户和商家资料
  test_merchants = [
    { email: 'merchant1@example.com', shop_name: '优品电子商城', status: 'submitted', 
      province: '广东省', city: '深圳市', district: '南山区', detail: '科技园南路88号' },
    { email: 'merchant2@example.com', shop_name: '鲜果乐园', status: 'approved',
      province: '浙江省', city: '杭州市', district: '西湖区', detail: '文三路200号' },
    { email: 'merchant3@example.com', shop_name: '时尚衣橱', status: 'rejected',
      province: '上海市', city: '上海市', district: '静安区', detail: '南京西路500号',
      reject_reason: '营业执照信息不清晰，请重新上传' },
    { email: 'merchant4@example.com', shop_name: '美味小厨', status: 'pending',
      province: '北京市', city: '北京市', district: '朝阳区', detail: '建国路100号' },
    { email: 'merchant5@example.com', shop_name: '健康药房', status: 'suspended',
      province: '四川省', city: '成都市', district: '武侯区', detail: '人民南路50号' }
  ]

  admin_user = AdminUser.first
  # Format admin ID as UUID for storage
  admin_uuid = admin_user ? MerchantProfile.format_admin_id_as_uuid(admin_user.id) : nil

  test_merchants.each do |m|
    user = User.find_or_create_by!(email: m[:email]) do |u|
      u.password = 'password123'
      u.password_confirmation = 'password123'
      u.phone = "138#{rand(10000000..99999999)}"
      u.nickname = m[:shop_name].gsub(/[商城园橱房]/, '')
    end

    mp = MerchantProfile.find_or_create_by!(user: user) do |profile|
      profile.shop_name = m[:shop_name]
      profile.status = m[:status]
      profile.address_province = m[:province]
      profile.address_city = m[:city]
      profile.address_district = m[:district]
      profile.address_detail = m[:detail]
      profile.bank_name = ['中国工商银行', '中国建设银行', '中国银行', '招商银行'].sample
      profile.bank_branch = "#{m[:city]}分行"
      profile.reject_reason = m[:reject_reason]
      
      if m[:status] == 'approved'
        profile.approved_at = Time.current - rand(1..30).days
        profile.approved_by_admin_id = admin_uuid
      elsif m[:status] == 'rejected'
        profile.rejected_at = Time.current - rand(1..15).days
        profile.rejected_by_admin_id = admin_uuid
      end
    end

    # 为已审批的商家创建审批记录
    if mp.persisted? && mp.review_logs.empty?
      case m[:status]
      when 'approved'
        mp.review_logs.create!(action: 'approve', operator_admin_id: admin_uuid, note: '审核通过')
      when 'rejected'
        mp.review_logs.create!(action: 'reject', operator_admin_id: admin_uuid, note: m[:reject_reason])
      when 'suspended'
        mp.review_logs.create!(action: 'approve', operator_admin_id: admin_uuid, note: '审核通过')
        mp.review_logs.create!(action: 'suspend', operator_admin_id: admin_uuid, note: '违规操作，暂停营业')
      end
    end
  end

  puts "Merchant test data seed done. Created #{test_merchants.size} test merchants."
end