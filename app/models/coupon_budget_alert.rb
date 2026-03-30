# frozen_string_literal: true

class CouponBudgetAlert < ApplicationRecord
  ALERT_TYPES = %w[quota_threshold budget_threshold quota_exhausted budget_exhausted].freeze
  STATUSES    = %w[pending acknowledged].freeze

  # === Associations ===
  belongs_to :coupon_template
  belongs_to :acknowledged_by, class_name: "AdminUser", optional: true,
             foreign_key: :acknowledged_by_id

  # === Validations ===
  validates :alert_type, presence: true, inclusion: { in: ALERT_TYPES }
  validates :status,     presence: true, inclusion: { in: STATUSES }

  # === Scopes ===
  scope :pending,      -> { where(status: "pending") }
  scope :acknowledged, -> { where(status: "acknowledged") }

  def acknowledge!(admin_user)
    update!(status: "acknowledged", acknowledged_by: admin_user, acknowledged_at: Time.current)
  end

  # === Ransack ===
  def self.ransackable_attributes(_auth_object = nil)
    %w[id alert_type status current_ratio coupon_template_id created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[coupon_template]
  end
end
