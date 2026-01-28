class Order < ApplicationRecord
  include AASM

  # === Associations ===
  # Note: customer_id and merchant_id are UUIDs, but User uses bigint IDs
  # So we use custom lookup methods instead of belongs_to
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
      transitions from: :paid, to: :accepted
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

  # Customer/Merchant lookup (UUID to User)
  def customer_user
    return nil if customer_id.blank?
    User.find_by(id: customer_id.to_s.split('-').last.to_i)
  end

  def merchant_user
    return nil if merchant_id.blank?
    User.find_by(id: merchant_id.to_s.split('-').last.to_i)
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

