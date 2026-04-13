# frozen_string_literal: true

class RiskEvent < ApplicationRecord
  include UuidIdentity

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

  # === Subject / Resolver Lookup (via UuidIdentity) ===
  # subject_id / resolved_by_id 存储格式：00000000-0000-0000-0000-{12 位 bigint ID}
  # Stored as: 00000000-0000-0000-0000-{12-digit bigint ID}

  def subject
    @subject ||= self.class.find_user_by_uuid(subject_id)
  end

  def resolved_by
    @resolved_by ||= self.class.find_admin_by_uuid(resolved_by_id)
  end

  # === Ransack ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id risk_rule_id status subject_id trigger_source resolved_at created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[risk_rule]
  end
end
