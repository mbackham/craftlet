# frozen_string_literal: true

class SettlementRule < ApplicationRecord
  # === Constants ===
  CYCLE_TYPES = %w[T+1 T+3 T+7 T+15 T+30].freeze
  CYCLE_DAYS_MAP = { "T+1" => 1, "T+3" => 3, "T+7" => 7, "T+15" => 15, "T+30" => 30 }.freeze

  # === Associations ===
  belongs_to :merchant_profile, optional: true  # null = 全局默认规则

  # === Validations ===
  validates :cycle_type, presence: true, inclusion: { in: CYCLE_TYPES }
  validates :cycle_days, presence: true, inclusion: { in: [1, 3, 7, 15, 30] }
  validates :deposit_deduction_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :penalty_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :min_settlement_amount, numericality: { greater_than_or_equal_to: 0 }
  validate :one_active_rule_per_merchant

  # === Scopes ===
  scope :active, -> { where(is_active: true) }
  scope :default_rule, -> { where(merchant_profile_id: nil).active }
  scope :for_merchant, ->(merchant_profile_id) {
    where(merchant_profile_id: merchant_profile_id).active
  }

  # === Class Methods ===
  # 获取商家适用的结算规则（优先商家自定义，否则全局默认）
  def self.rule_for(merchant_profile)
    for_merchant(merchant_profile.id).first || default_rule.first
  end

  # === Display Helpers ===
  def merchant_name
    merchant_profile&.shop_name || "全局默认"
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id merchant_profile_id cycle_type cycle_days is_active created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[merchant_profile]
  end

  private

  # 同一商家（或全局）最多只能有一条活跃规则
  def one_active_rule_per_merchant
    return unless is_active?

    scope = self.class.where(merchant_profile_id: merchant_profile_id, is_active: true)
    scope = scope.where.not(id: id) if persisted?
    if scope.exists?
      target = merchant_profile_id.present? ? "该商家" : "全局"
      errors.add(:base, "#{target}已有一条活跃的结算规则")
    end
  end
end
