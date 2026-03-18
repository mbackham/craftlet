# frozen_string_literal: true

class FundAlert < ApplicationRecord
  # === Associations ===
  belongs_to :subject, polymorphic: true
  belongs_to :handler_admin, class_name: "AdminUser", foreign_key: :handler_admin_id, optional: true

  # === Enums ===
  enum alert_type: { payment: "payment", refund: "refund", settlement: "settlement" }
  enum status: { pending: "pending", acknowledged: "acknowledged", ignored: "ignored" }

  # === Validations ===
  validates :alert_type, presence: true
  validates :subject_type, presence: true
  validates :subject_id, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :threshold, presence: true, numericality: { greater_than: 0 }

  # === Scopes ===
  scope :recent, -> { order(created_at: :desc) }
  scope :today,  -> { where(created_at: Time.current.beginning_of_day..Time.current.end_of_day) }

  # === Ransack ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id alert_type subject_type subject_id amount threshold status handler_admin_id created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[subject handler_admin]
  end
end
