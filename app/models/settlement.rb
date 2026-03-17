# frozen_string_literal: true

class Settlement < ApplicationRecord
  include AASM

  # === Associations ===
  belongs_to :merchant_profile
  has_many :settlement_items, dependent: :destroy
  has_many :orders, through: :settlement_items
  has_many :settlement_exceptions, dependent: :destroy
  has_many :invoices, dependent: :destroy

  # === Validations ===
  validates :settlement_no, presence: true, uniqueness: true
  validates :period_start, :period_end, presence: true
  validates :net_amount, numericality: { greater_than_or_equal_to: 0 }
  validate :period_end_after_start

  # === Callbacks ===
  before_validation :generate_settlement_no, on: :create

  # === AASM State Machine ===
  aasm column: "status" do
    state :pending_review, initial: true
    state :approved, :rejected, :paid_out, :confirmed, :funds_frozen, :failed

    # 财务审批通过
    event :approve do
      transitions from: :pending_review, to: :approved
    end

    # 财务审批拒绝
    event :reject do
      transitions from: :pending_review, to: :rejected
    end

    # 出纳打款
    event :payout do
      transitions from: :approved, to: :paid_out
    end

    # 确认到账
    event :confirm_arrival do
      transitions from: :paid_out, to: :confirmed
    end

    # 冻结
    event :freeze_settlement do
      transitions from: [:pending_review, :approved], to: :funds_frozen
    end

    # 解冻 → 回到待审核
    event :unfreeze do
      transitions from: :funds_frozen, to: :pending_review
    end

    # 标记失败
    event :mark_failed do
      transitions from: [:approved, :paid_out], to: :failed
    end

    # 重试 → 回到待审核
    event :retry_settlement do
      transitions from: [:failed, :funds_frozen], to: :pending_review
    end
  end

  # === Scopes ===
  scope :pending, -> { where(status: "pending_review") }
  scope :by_merchant, ->(merchant_profile_id) { where(merchant_profile_id: merchant_profile_id) }

  # === Display Helpers ===
  def status_label
    I18n.t("settlement_statuses.#{status}", default: status.to_s.humanize)
  end

  def merchant_name
    merchant_profile&.shop_name || "-"
  end

  def period_display
    "#{period_start} ~ #{period_end}"
  end

  def approved_by_admin
    AdminUser.find_by(id: approved_by) if approved_by.present?
  end

  def paid_out_by_admin
    AdminUser.find_by(id: paid_out_by) if paid_out_by.present?
  end

  # === Calculation ===
  def calculate_amounts!
    self.total_order_amount = settlement_items.sum(:order_amount)
    self.total_refund_amount = settlement_items.sum(:refund_amount)

    rule = SettlementRule.rule_for(merchant_profile)
    if rule
      gross = total_order_amount - total_refund_amount
      self.deposit_deduction = (gross * rule.deposit_deduction_rate).round(2)
      self.penalty_amount = (gross * rule.penalty_rate).round(2)
      self.net_amount = [gross - deposit_deduction - penalty_amount, 0].max
    else
      self.net_amount = [total_order_amount - total_refund_amount, 0].max
    end

    save!
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id settlement_no merchant_profile_id status period_start period_end
       net_amount total_order_amount created_at approved_at paid_out_at confirmed_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[merchant_profile settlement_items settlement_exceptions invoices]
  end

  private

  def generate_settlement_no
    return if settlement_no.present?

    date_part = Time.current.strftime("%Y%m%d")
    seq = self.class.where("settlement_no LIKE ?", "ST#{date_part}%").count + 1
    self.settlement_no = "ST#{date_part}#{seq.to_s.rjust(4, '0')}"
  end

  def period_end_after_start
    return if period_start.blank? || period_end.blank?

    if period_end < period_start
      errors.add(:period_end, "必须晚于或等于开始日期")
    end
  end
end
