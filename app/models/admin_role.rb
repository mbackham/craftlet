class AdminRole < ApplicationRecord
  has_many :admin_user_roles, dependent: :destroy
  has_many :users, through: :admin_user_roles

  has_many :admin_role_permissions, dependent: :destroy
  has_many :admin_permissions, through: :admin_role_permissions

  validates :name, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true
end
