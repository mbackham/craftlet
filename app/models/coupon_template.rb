# frozen_string_literal: true

class CouponTemplate < ApplicationRecord
  # === Constants ===
  TYPES    = %w[fixed_amount discount redeem_code].freeze
  STATUSES = %w[draft active inactive].freeze

  # === Associations ===
  has_many :coupons, dependent: :destroy
  has_many :budget_alerts, class_name: "CouponBudgetAlert", dependent: :destroy

  # === Validations ===
  validates :name,        presence: true
  validates :coupon_type, presence: true, inclusion: { in: TYPES }
  validates :status,      presence: true, inclusion: { in: STATUSES }
  validates :face_value,  presence: true, numericality: { greater_than_or_equal_to: 0.01 }
  validates :face_value,  numericality: { less_than: 1, greater_than_or_equal_to: 0.01 }, if: :discount?
  validates :min_order_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :per_user_limit,   numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :total_quota,      numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
  validates :budget_amount,    numericality: { greater_than_or_equal_to: 0.01 }, allow_nil: true
  validates :budget_alert_threshold,
            numericality: { greater_than_or_equal_to: 0.01, less_than_or_equal_to: 1 }, allow_nil: true

  # === Scopes ===
  scope :active,   -> { where(status: "active") }
  scope :draft,    -> { where(status: "draft") }
  scope :inactive, -> { where(status: "inactive") }
  scope :quota_available, -> { where("total_quota IS NULL OR issued_count < total_quota") }

  # === Type Helpers ===
  def fixed_amount? = coupon_type == "fixed_amount"
  def discount?     = coupon_type == "discount"
  def redeem_code?  = coupon_type == "redeem_code"

  # === Status Helpers ===
  def activatable?   = status == "draft"
  def deactivatable? = status == "active"

  def activate!   = update!(status: "active")
  def deactivate! = update!(status: "inactive")

  # === Quota / Budget ===
  def quota_used_ratio
    return nil if total_quota.nil? || total_quota.zero?
    issued_count.to_f / total_quota
  end

  def budget_used_ratio
    return nil if budget_amount.nil? || budget_amount.zero?
    used_amount / budget_amount
  end

  def quota_exhausted?
    total_quota.present? && issued_count >= total_quota
  end

  def budget_exhausted?
    budget_amount.present? && used_amount >= budget_amount
  end

  def issuable?
    status == "active" && !quota_exhausted? && !budget_exhausted?
  end

  # === Grant Rules Helpers ===
  def for_new_user? = grant_rules["new_user"].present?
  def for_birthday? = grant_rules["birthday"].present?
  def min_level     = grant_rules["min_level"].to_i

  # === Coupon Issuance ===
  def issue_to!(user, grant_type: "manual")
    raise "优惠券模板未激活" unless status == "active"
    raise "发放配额已耗尽" if quota_exhausted?
    raise "预算已耗尽" if budget_exhausted?

    if per_user_limit.to_i > 0
      existing = coupons.where(user_id: user.id).count
      raise "已超过每人领取上限" if existing >= per_user_limit
    end

    expires = compute_expires_at
    code    = generate_unique_code

    coupon = nil
    with_lock do
      reload
      raise "发放配额已耗尽" if quota_exhausted?
      coupon = coupons.create!(
        user_id:    user.id,
        code:       code,
        status:     "unused",
        grant_type: grant_type,
        granted_at: Time.current,
        expires_at: expires
      )
      increment!(:issued_count)
    end

    check_and_create_budget_alert!
    coupon
  end

  # Public so Coupon#use! can call it after updating used_amount
  def check_and_create_budget_alert!
    threshold = budget_alert_threshold || 0.8

    if total_quota.present? && quota_used_ratio
      ratio = quota_used_ratio
      if ratio >= 1.0
        create_alert_if_needed!("quota_exhausted", ratio)
      elsif ratio >= threshold
        create_alert_if_needed!("quota_threshold", ratio)
      end
    end

    if budget_amount.present? && budget_used_ratio
      ratio = budget_used_ratio
      if ratio >= 1.0
        create_alert_if_needed!("budget_exhausted", ratio)
      elsif ratio >= threshold
        create_alert_if_needed!("budget_threshold", ratio)
      end
    end
  end

  # === Ransack ===
  def self.ransackable_attributes(_auth_object = nil)
    %w[id name coupon_type status face_value min_order_amount total_quota issued_count
       budget_amount used_amount created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[coupons budget_alerts]
  end

  private

  def compute_expires_at
    if valid_days.present?
      valid_days.days.from_now
    elsif valid_until.present?
      valid_until
    end
  end

  def generate_unique_code
    loop do
      code = SecureRandom.alphanumeric(12).upcase
      return code unless Coupon.exists?(code: code)
    end
  end

  def create_alert_if_needed!(alert_type, ratio)
    return if budget_alerts.where(alert_type: alert_type, status: "pending").exists?

    budget_alerts.create!(
      alert_type:    alert_type,
      current_ratio: ratio,
      status:        "pending"
    )
  end
end
