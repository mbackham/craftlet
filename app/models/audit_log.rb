class AuditLog < ApplicationRecord
  # Don't use polymorphic association directly due to UUID/bigint mismatch
  # belongs_to :actor, polymorphic: true, optional: true
  
  validates :action, presence: true

  # Custom actor method to handle UUID to bigint conversion
  def actor
    return nil if actor_type.blank? || actor_id.blank?
    return nil if actor_type == 'System'
    
    begin
      klass = actor_type.constantize
      # Extract the numeric ID from UUID format (last 12 digits)
      numeric_id = actor_id.to_s.split('-').last.to_i
      klass.find_by(id: numeric_id)
    rescue NameError, ActiveRecord::RecordNotFound
      nil
    end
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[action target_type target_id ip ip_address user_agent request_id created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    [] # Exclude actor to avoid UUID/bigint type mismatch
  end
end
