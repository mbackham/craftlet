class AdminUserRole < ApplicationRecord
  belongs_to :user
  belongs_to :admin_role

  validates :user_id, uniqueness: { scope: :admin_role_id }

  def self.ransackable_attributes(auth_object = nil)
    %w[user_id admin_role_id created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[user admin_role]
  end
end
