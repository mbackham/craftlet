class AdminUser < ApplicationRecord
  # Include default devise modules.
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable,
         :lockable, :trackable, :timeoutable

  enum :role, { admin: "admin", operator: "operator" }, default: "admin"

  # Admin RBAC associations
  has_many :admin_user_roles, foreign_key: :user_id, dependent: :destroy, inverse_of: :user
  has_many :admin_roles, through: :admin_user_roles

  validates :role, presence: true, inclusion: { in: roles.keys }

  # 管理员密码强度校验（不修改 Devise 全局 password_length，避免影响前台 User）
  validate :password_complexity, if: :password_required?

  # 管理员会话超时：30 分钟无操作自动登出（覆盖 Devise 全局 timeout_in）
  def timeout_in
    30.minutes
  end

  # Admin RBAC methods
  def admin_has_role?(code)
    admin_roles.where(code: code).exists?
  end

  def admin_can?(permission_code)
    # Super admin (role enum) can do everything
    return true if admin?

    # Check via RBAC permissions
    AdminPermission.joins(admin_roles: :admin_user_roles)
                   .where(admin_user_roles: { user_id: id })
                   .where(code: permission_code)
                   .exists?
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[email role created_at updated_at sign_in_count current_sign_in_at last_sign_in_at locked_at]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end

  private

  # 至少 12 位，包含大写字母、小写字母、数字和特殊字符
  def password_complexity
    return if password.blank?

    unless password.length >= 12
      errors.add(:password, "长度至少为12位")
    end

    unless password.match?(/[a-z]/)
      errors.add(:password, "必须包含至少一个小写字母")
    end

    unless password.match?(/[A-Z]/)
      errors.add(:password, "必须包含至少一个大写字母")
    end

    unless password.match?(/\d/)
      errors.add(:password, "必须包含至少一个数字")
    end

    unless password.match?(/[^a-zA-Z\d]/)
      errors.add(:password, "必须包含至少一个特殊字符")
    end
  end
end
