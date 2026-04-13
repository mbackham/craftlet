class Refund < ApplicationRecord
  include UuidIdentity

  # === Constants ===
  STATUSES = %w[init pending succeeded failed].freeze

  # === Associations ===
  belongs_to :order
  belongs_to :payment

  # === Display Helpers ===
  def status_label
    I18n.t("refund_statuses.#{status}", default: status.to_s.humanize)
  end

  # === Requester Lookup (via UuidIdentity) ===
  # requested_by_id 存储格式：00000000-0000-0000-0000-{12 位 bigint ID}
  # Stored as: 00000000-0000-0000-0000-{12-digit bigint ID}
  def requester
    @requester ||= self.class.find_user_by_uuid(requested_by_id)
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id order_id payment_id amount reason status provider_refund_no succeeded_at created_at
       request_payload response_payload notify_payload]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[order payment]
  end
end
