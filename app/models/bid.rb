# frozen_string_literal: true

class Bid < ApplicationRecord
  include UuidIdentity

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

  # === Bidder Lookup (via UuidIdentity) ===
  # bidder_id 存储格式：00000000-0000-0000-0000-{12 位 bigint ID}
  # bidder_id is stored as: 00000000-0000-0000-0000-{12-digit bigint ID}
  def bidder
    @bidder ||= self.class.find_user_by_uuid(bidder_id)
  end

  def bidder=(user)
    self.bidder_id = self.class.id_to_uuid(user&.id)
    @bidder = user
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id order_id bidder_id amount status created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[order]
  end
end
