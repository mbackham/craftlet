class Refund < ApplicationRecord
  # === Constants ===
  STATUSES = %w[init pending succeeded failed].freeze

  # === Associations ===
  belongs_to :order
  belongs_to :payment

  # === Display Helpers ===
  def status_label
    I18n.t("refund_statuses.#{status}", default: status.to_s.humanize)
  end

  # Requester lookup (UUID to User)
  def requester
    return nil if requested_by_id.blank?
    User.find_by(id: requested_by_id.to_s.split('-').last.to_i)
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id order_id payment_id amount reason status provider_refund_no succeeded_at created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[order payment]
  end
end
