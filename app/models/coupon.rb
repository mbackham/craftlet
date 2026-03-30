# frozen_string_literal: true

class Coupon < ApplicationRecord
  # === Constants ===
  STATUSES    = %w[unused used expired locked].freeze
  GRANT_TYPES = %w[manual new_user birthday level_up redeem].freeze

  # === Associations ===
  belongs_to :coupon_template

  # === Validations ===
  validates :user_id,    presence: true
  validates :code,       presence: true, uniqueness: true
  validates :status,     presence: true, inclusion: { in: STATUSES }
  validates :grant_type, presence: true, inclusion: { in: GRANT_TYPES }
  validates :granted_at, presence: true

  # === Scopes ===
  scope :unused,  -> { where(status: "unused") }
  scope :used,    -> { where(status: "used") }
  scope :expired, -> { where(status: "expired") }
  scope :valid,   -> { unused.where("expires_at IS NULL OR expires_at > ?", Time.current) }

  # === Status Helpers ===
  def usable?
    status == "unused" && (expires_at.nil? || expires_at > Time.current)
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  # Calculate discount for a given order amount
  # Returns 0 if not applicable
  def calculate_discount(order_amount)
    return 0 unless usable?

    tmpl = coupon_template
    return 0 if tmpl.min_order_amount > 0 && order_amount < tmpl.min_order_amount

    case tmpl.coupon_type
    when "fixed_amount"
      [tmpl.face_value, order_amount].min
    when "discount"
      (order_amount * (1 - tmpl.face_value)).round(2)
    when "redeem_code"
      [tmpl.face_value, order_amount].min
    else
      0
    end
  end

  # Mark as used by an order
  def use!(order_id:, discount_amount:)
    raise "优惠券不可用" unless usable?

    transaction do
      update!(
        status:          "used",
        used_at:         Time.current,
        order_id:        order_id,
        discount_amount: discount_amount
      )
      coupon_template.increment!(:used_amount, discount_amount)
      coupon_template.check_and_create_budget_alert!
    end
  end

  # Expire stale coupons (run via cron/sidekiq)
  def self.expire_stale!
    where(status: "unused").where("expires_at <= ?", Time.current).update_all(status: "expired")
  end

  # === Ransack ===
  def self.ransackable_attributes(_auth_object = nil)
    %w[id code status grant_type user_id order_id granted_at used_at expires_at coupon_template_id]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[coupon_template]
  end
end
