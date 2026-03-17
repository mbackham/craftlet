# frozen_string_literal: true

class SettlementItem < ApplicationRecord
  # === Associations ===
  belongs_to :settlement
  belongs_to :order

  # === Validations ===
  validates :order_id, uniqueness: { scope: :settlement_id, message: "该订单已在此结算单中" }
  validates :order_amount, :refund_amount, :net_amount,
            numericality: { greater_than_or_equal_to: 0 }

  # === Callbacks ===
  before_validation :calculate_net_amount, on: :create

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id settlement_id order_id order_amount refund_amount net_amount created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[settlement order]
  end

  private

  def calculate_net_amount
    self.net_amount = [order_amount.to_d - refund_amount.to_d, 0].max
  end
end
