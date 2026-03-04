class AdminUserRole < ApplicationRecord
  belongs_to :user, class_name: 'AdminUser', inverse_of: :admin_user_roles, optional: true
  belongs_to :admin_role

  validates :user_id, presence: true, uniqueness: { scope: :admin_role_id }

  def self.ransackable_attributes(auth_object = nil)
    %w[user_id admin_role_id created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[user admin_role]
  end
end
