class AuditLog < ApplicationRecord
  include UuidIdentity

  # Don't use polymorphic association directly due to UUID/bigint mismatch
  # belongs_to :actor, polymorphic: true, optional: true

  validates :action, presence: true

  # === Actor Lookup (via UuidIdentity) ===
  # actor_id 存储格式：00000000-0000-0000-0000-{12 位 bigint ID}，actor_type 为 'User' 或 'AdminUser'
  # actor_id is stored as: 00000000-0000-0000-0000-{12-digit bigint ID}; actor_type is 'User' or 'AdminUser'
  def actor
    return nil if actor_type.blank? || actor_id.blank?
    return nil if actor_type == 'System'

    case actor_type
    when 'User'
      self.class.find_user_by_uuid(actor_id)
    when 'AdminUser'
      self.class.find_admin_by_uuid(actor_id)
    else
      begin
        klass = actor_type.constantize
        klass.find_by(id: self.class.uuid_to_id(actor_id))
      rescue NameError
        nil
      end
    end
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[action target_type target_id ip ip_address user_agent request_id created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    [] # Exclude actor to avoid UUID/bigint type mismatch
  end
end
