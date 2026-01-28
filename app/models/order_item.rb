# frozen_string_literal: true

class OrderItem < ApplicationRecord
  # === Associations ===
  belongs_to :order
  belongs_to :item, polymorphic: true, optional: true

  # === Validations ===
  validates :item_type, presence: true
  validates :item_id, presence: true

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id order_id item_type item_id name unit_price quantity subtotal created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[order]
  end
end
