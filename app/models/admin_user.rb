class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, 
         :recoverable, :rememberable, :validatable

  enum :role, { admin: "admin", operator: "operator" }, default: "admin"

  validates :role, presence: true, inclusion: { in: roles.keys }
end
