class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  has_many :roles, dependent: :destroy
  has_one :merchant_profile, dependent: :destroy
  has_many :customer_orders, class_name: "Order", foreign_key: "customer_id"
  has_many :merchant_orders, class_name: "Order", foreign_key: "merchant_id"

  # Admin RBAC associations
  has_many :admin_user_roles, dependent: :destroy
  has_many :admin_roles, through: :admin_user_roles
  has_many :audit_logs, foreign_key: :actor_id, dependent: :nullify

  def has_role?(role_type)
    roles.where(role_type: role_type, is_active: true).exists?
  end

  def customer?
    has_role?("customer")
  end

  def merchant?
    has_role?("merchant")
  end

  # Admin RBAC methods
  def admin_has_role?(code)
    admin_roles.where(code: code).exists?
  end

  def admin_can?(permission_code)
    AdminPermission.joins(admin_roles: :admin_user_roles)
                   .where(admin_user_roles: { user_id: id })
                   .where(code: permission_code)
                   .exists?
  end
end
