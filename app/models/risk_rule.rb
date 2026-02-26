# frozen_string_literal: true

class RiskRule < ApplicationRecord
  # === Constants ===
  CATEGORIES = %w[refund order merchant general].freeze
  SEVERITIES = %w[low medium high critical].freeze

  # === Associations ===
  has_many :risk_events, dependent: :destroy

  # === Validations ===
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :severity, inclusion: { in: SEVERITIES }

  # === Scopes ===
  scope :enabled,  -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }

  # === Display Helpers ===
  def severity_label
    I18n.t("risk_severities.#{severity}", default: severity.humanize)
  end

  def category_label
    I18n.t("risk_categories.#{category}", default: category.humanize)
  end

  # === Ransack ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id code name category severity enabled created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[risk_events]
  end
end
