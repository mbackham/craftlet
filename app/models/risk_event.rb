# frozen_string_literal: true

class RiskEvent < ApplicationRecord
  # === Constants ===
  STATUSES = %w[pending ignored processed].freeze

  # === Associations ===
  belongs_to :risk_rule

  # === Validations ===
  validates :status,     presence: true, inclusion: { in: STATUSES }
  validates :subject_id, presence: true

  # === Scopes ===
  scope :pending,   -> { where(status: "pending") }
  scope :ignored,   -> { where(status: "ignored") }
  scope :processed, -> { where(status: "processed") }
  scope :unresolved, -> { where(status: "pending") }

  # === Display Helpers ===
  def status_label
    I18n.t("risk_event_statuses.#{status}", default: status.humanize)
  end

  # Subject lookup (UUID to User)
  def subject
    return nil if subject_id.blank?
    id_num = subject_id.to_s.split('-').last.to_i
    User.find_by(id: id_num)
  end

  # Resolver lookup
  def resolved_by
    return nil if resolved_by_id.blank?
    id_num = resolved_by_id.to_s.split('-').last.to_i
    AdminUser.find_by(id: id_num)
  end

  # === Ransack ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id risk_rule_id status subject_id trigger_source resolved_at created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[risk_rule]
  end
end
