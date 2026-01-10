class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :roles, dependent: :destroy
  has_one :merchant_profile, dependent: :destroy
  has_many :customer_orders, class_name: "Order", foreign_key: "customer_id"
  has_many :merchant_orders, class_name: "Order", foreign_key: "merchant_id"

  def has_role?(role_type)
    roles.where(role_type: role_type, is_active: true).exists?
  end

  def customer?
    has_role?("customer")
  end

  def merchant?
    has_role?("merchant")
  end
end
