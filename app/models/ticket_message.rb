# frozen_string_literal: true

class TicketMessage < ApplicationRecord
  include UuidIdentity

  # === Associations ===
  belongs_to :ticket
  has_many :attachments, class_name: "TicketAttachment", dependent: :destroy

  # === Validations ===
  validates :content,   presence: true
  validates :sender_id, presence: true

  # === Scopes ===
  scope :public_messages,  -> { where(internal: false) }
  scope :internal_notes,   -> { where(internal: true) }

  # === Sender Lookup (via UuidIdentity) ===
  # sender_id 存储格式：00000000-0000-0000-0000-{12 位 bigint ID}
  # sender_id is stored as: 00000000-0000-0000-0000-{12-digit bigint ID}

  # 多态 sender：User 或 AdminUser
  # Polymorphic sender: User or AdminUser
  def sender
    return nil if sender_id.blank?

    if sender_type == "AdminUser"
      self.class.find_admin_by_uuid(sender_id)
    else
      self.class.find_user_by_uuid(sender_id)
    end
  end

  def sender_display
    s = sender
    return sender_id if s.nil?
    s.respond_to?(:email) ? s.email : sender_id
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id ticket_id sender_id sender_type internal created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[ticket attachments]
  end
end
