class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, 
         :recoverable, :rememberable, :validatable

  enum :role, { admin: "admin", operator: "operator" }, default: "admin"

  # Admin RBAC associations
  has_many :admin_user_roles, foreign_key: :user_id, dependent: :destroy
  has_many :admin_roles, through: :admin_user_roles

  validates :role, presence: true, inclusion: { in: roles.keys }

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
    %w[email role created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end
end
