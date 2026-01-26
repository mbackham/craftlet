class AdminPermission < ApplicationRecord
  has_many :admin_role_permissions, dependent: :destroy
  has_many :admin_roles, through: :admin_role_permissions

  validates :name, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true
end
