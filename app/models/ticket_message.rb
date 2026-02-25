# frozen_string_literal: true

class TicketMessage < ApplicationRecord
  # === Associations ===
  belongs_to :ticket
  has_many :attachments, class_name: "TicketAttachment", dependent: :destroy

  # === Validations ===
  validates :content,   presence: true
  validates :sender_id, presence: true

  # === Scopes ===
  scope :public_messages,  -> { where(internal: false) }
  scope :internal_notes,   -> { where(internal: true) }

  # Sender lookup (UUID to User/AdminUser)
  def sender
    return nil if sender_id.blank?
    if sender_type == "AdminUser"
      id_num = sender_id.to_s.split('-').last.to_i
      AdminUser.find_by(id: id_num)
    else
      id_num = sender_id.to_s.split('-').last.to_i
      User.find_by(id: id_num)
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
