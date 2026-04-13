class Order < ApplicationRecord
  include AASM
  include UuidIdentity

  # === Associations ===
  # Note: customer_id and merchant_id are UUID-encoded bigint IDs (see UuidIdentity concern).
  # Direct belongs_to is not used; use #customer / #merchant instance methods instead.
  has_many :payments, dependent: :destroy
  has_many :refunds, dependent: :destroy
  has_many :order_items, dependent: :destroy
  has_many :bids, dependent: :destroy

  # === AASM State Machine ===
  aasm column: "status" do
    state :created, initial: true
    state :paid, :accepted, :producing, :delivered, :completed, :canceled, :refunded

    event :mark_paid do
      transitions from: :created, to: :paid
    end

    event :accept do
      transitions from: :paid, to: :accepted, guard: :merchant_active?
    end

    event :start_producing do
      transitions from: :accepted, to: :producing
    end

    event :deliver do
      transitions from: :producing, to: :delivered
    end

    event :complete do
      transitions from: :delivered, to: :completed
    end

    event :cancel do
      transitions from: [:created, :paid, :accepted], to: :canceled
    end

    event :refund do
      transitions from: [:paid, :accepted, :producing, :delivered], to: :refunded
    end
  end

  # === Display Helpers ===
  def status_label
    I18n.t("order_statuses.#{status}", default: status.to_s.humanize)
  end

  # === Customer / Merchant Lookup (via UuidIdentity) ===
  # customer_id / merchant_id 存储格式：00000000-0000-0000-0000-{12 位 bigint ID}
  # customer_id / merchant_id are stored as: 00000000-0000-0000-0000-{12-digit bigint ID}

  def customer
    @customer ||= self.class.find_user_by_uuid(customer_id)
  end

  def merchant
    @merchant ||= self.class.find_user_by_uuid(merchant_id)
  end

  # 向下兼容别名（ActiveAdmin 视图中引用了 customer_user / merchant_user）
  # Backward-compatible aliases (ActiveAdmin views reference customer_user / merchant_user)
  alias_method :customer_user, :customer
  alias_method :merchant_user, :merchant

  def customer=(user)
    self.customer_id = self.class.id_to_uuid(user&.id)
    @customer = user
  end

  def merchant=(user)
    self.merchant_id = self.class.id_to_uuid(user&.id)
    @merchant = user
  end

  # === Frozen Participant Guards ===
  # Used by AASM accept guard and AssignMerchantService
  def merchant_active?
    user = merchant
    return false unless user
    return false unless user.status == "active"

    profile = user.merchant_profile
    return false unless profile&.approved?

    true
  end

  def customer_active?
    user = customer
    return false unless user
    user.status == "active"
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id order_no status total_amount currency customer_id merchant_id 
       created_at paid_at completed_at canceled_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[payments refunds order_items bids]
  end
end

