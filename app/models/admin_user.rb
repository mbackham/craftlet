class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, 
         :recoverable, :rememberable, :validatable

  enum :role, { admin: "admin", operator: "operator" }, default: "admin"

  validates :role, presence: true, inclusion: { in: roles.keys }

  def self.ransackable_attributes(auth_object = nil)
    %w[email role created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end
end
