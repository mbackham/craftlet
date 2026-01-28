class Payment < ApplicationRecord
  # === Constants ===
  STATUSES = %w[init pending paid failed refunded].freeze
  CHANNELS = %w[wechat alipay bank_transfer].freeze

  # === Associations ===
  belongs_to :order
  has_many :refunds, dependent: :destroy

  # === Display Helpers ===
  def status_label
    I18n.t("payment_statuses.#{status}", default: status.to_s.humanize)
  end

  def channel_label
    I18n.t("payment_channels.#{channel}", default: channel.to_s.humanize)
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id order_id channel status amount currency provider_trade_no paid_at created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[order refunds]
  end
end
