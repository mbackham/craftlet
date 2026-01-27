class AuditLog < ApplicationRecord
  belongs_to :actor, class_name: "User", optional: true
  validates :action, presence: true

  def self.ransackable_attributes(auth_object = nil)
    %w[action target_type target_id ip ip_address user_agent request_id created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    [] # Exclude actor to avoid UUID/bigint type mismatch
  end
end
