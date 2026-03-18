class Payment < ApplicationRecord
  # === Constants ===
  STATUSES = %w[init pending paid failed refunded].freeze
  CHANNELS = %w[wechat alipay bank_transfer].freeze

  # === Associations ===
  belongs_to :order
  has_many :refunds, dependent: :destroy

  # === Callbacks ===
  # 支付状态变为 paid 后检测大额预警（after_update_commit = 事务提交后，不阻断主流程）
  after_update_commit :detect_large_amount, if: :just_paid?

  # === Display Helpers ===
  def status_label
    I18n.t("payment_statuses.#{status}", default: status.to_s.humanize)
  end

  def channel_label
    I18n.t("payment_channels.#{channel}", default: channel.to_s.humanize)
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id order_id channel status amount currency provider_trade_no paid_at created_at
       request_payload response_payload notify_payload]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[order refunds]
  end

  private

  def just_paid?
    saved_change_to_status? && status == "paid"
  end

  def detect_large_amount
    FundMonitoring::LargeAmountDetector.call(self)
  rescue => e
    Rails.logger.warn("[FundMonitoring] LargeAmountDetector error for Payment##{id}: #{e.message}")
  end
end

