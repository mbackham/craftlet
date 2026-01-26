class AdminUserRole < ApplicationRecord
  belongs_to :user
  belongs_to :admin_role

  validates :user_id, uniqueness: { scope: :admin_role_id }
end
