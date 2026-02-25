# frozen_string_literal: true

class TicketAttachment < ApplicationRecord
  # === Associations ===
  belongs_to :ticket_message

  # === Validations ===
  validates :file_name, presence: true

  # === Display Helpers ===
  def download_link
    url.presence || oss_key
  end

  def file_size_display
    return nil if file_size.blank?
    if file_size > 1_048_576
      "#{(file_size / 1_048_576.0).round(1)} MB"
    elsif file_size > 1024
      "#{(file_size / 1024.0).round(1)} KB"
    else
      "#{file_size} B"
    end
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id ticket_message_id file_name file_type created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[ticket_message]
  end
end
