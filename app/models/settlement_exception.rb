# frozen_string_literal: true

class SettlementException < ApplicationRecord
  # === Constants ===
  EXCEPTION_TYPES = %w[payout_failed amount_mismatch merchant_frozen].freeze
  STATUSES = %w[pending processing resolved ignored].freeze

  # === Associations ===
  belongs_to :settlement

  # === Validations ===
  validates :exception_type, presence: true, inclusion: { in: EXCEPTION_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }

  # === Scopes ===
  scope :pending, -> { where(status: "pending") }
  scope :unresolved, -> { where(status: %w[pending processing]) }

  # === Display Helpers ===
  def status_label
    I18n.t("settlement_exception_statuses.#{status}", default: status.to_s.humanize)
  end

  def exception_type_label
    I18n.t("settlement_exception_types.#{exception_type}", default: exception_type.to_s.humanize)
  end

  def resolved_by_admin
    AdminUser.find_by(id: resolved_by) if resolved_by.present?
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id settlement_id exception_type status created_at resolved_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[settlement]
  end
end
