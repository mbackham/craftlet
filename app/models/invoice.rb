# frozen_string_literal: true

class Invoice < ApplicationRecord
  include AASM

  # === Constants ===
  INVOICE_TYPES = %w[normal special].freeze

  # === Associations ===
  belongs_to :settlement
  belongs_to :merchant_profile

  # === Validations ===
  validates :invoice_no, presence: true, uniqueness: true
  validates :invoice_type, presence: true, inclusion: { in: INVOICE_TYPES }
  validates :amount, numericality: { greater_than_or_equal_to: 0.01, less_than_or_equal_to: 9_999_999_999.99 }

  # === Callbacks ===
  before_validation :generate_invoice_no, on: :create
  before_validation :set_requested_at, on: :create

  # === AASM State Machine ===
  aasm column: "status" do
    state :requested, initial: true
    state :issued, :shipped, :received, :rejected

    event :issue do
      transitions from: :requested, to: :issued
    end

    event :ship do
      transitions from: :issued, to: :shipped
    end

    event :receive do
      transitions from: :shipped, to: :received
    end

    event :reject_invoice do
      transitions from: :requested, to: :rejected
    end
  end

  # === Scopes ===
  scope :pending_issue, -> { where(status: "requested") }

  # === Display Helpers ===
  def status_label
    I18n.t("invoice_statuses.#{status}", default: status.to_s.humanize)
  end

  def invoice_type_label
    I18n.t("invoice_types.#{invoice_type}", default: invoice_type.to_s.humanize)
  end

  def issued_by_admin
    AdminUser.find_by(id: issued_by) if issued_by.present?
  end

  def merchant_name
    merchant_profile&.shop_name || "-"
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id invoice_no settlement_id merchant_profile_id invoice_type status
       amount title tax_no tracking_no created_at issued_at shipped_at received_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[settlement merchant_profile]
  end

  private

  def generate_invoice_no
    return if invoice_no.present?

    date_part = Time.current.strftime("%Y%m%d")
    seq = self.class.where("invoice_no LIKE ?", "INV#{date_part}%").count + 1
    self.invoice_no = "INV#{date_part}#{seq.to_s.rjust(4, '0')}"
  end

  def set_requested_at
    self.requested_at ||= Time.current
  end
end
