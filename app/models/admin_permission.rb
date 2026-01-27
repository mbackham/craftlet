class AdminPermission < ApplicationRecord
  has_many :admin_role_permissions, dependent: :destroy
  has_many :admin_roles, through: :admin_role_permissions

  validates :name, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true

  def self.ransackable_attributes(auth_object = nil)
    %w[name code created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[admin_roles]
  end
end

