# frozen_string_literal: true

class Bid < ApplicationRecord
  # === Constants ===
  STATUSES = %w[pending accepted rejected].freeze

  # === Associations ===
  belongs_to :order

  # === Validations ===
  validates :bidder_id, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }

  # === Scopes ===
  scope :pending, -> { where(status: 'pending') }
  scope :accepted, -> { where(status: 'accepted') }
  scope :rejected, -> { where(status: 'rejected') }

  # === Status Methods ===
  def pending?
    status == 'pending'
  end

  def accepted?
    status == 'accepted'
  end

  def rejected?
    status == 'rejected'
  end

  # === Display Helpers ===
  def status_label
    I18n.t("bid_statuses.#{status}", default: status.humanize)
  end

  # Bidder lookup (UUID to User)
  def bidder
    return nil if bidder_id.blank?
    User.find_by(id: bidder_id.to_s.split('-').last.to_i)
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id order_id bidder_id amount status created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[order]
  end
end
