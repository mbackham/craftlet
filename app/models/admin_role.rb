class AdminRole < ApplicationRecord
  has_many :admin_user_roles, dependent: :destroy
  has_many :users, through: :admin_user_roles

  has_many :admin_role_permissions, dependent: :destroy
  has_many :admin_permissions, through: :admin_role_permissions

  validates :name, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true

  def self.ransackable_attributes(auth_object = nil)
    %w[name code created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[admin_permissions users]
  end
end

