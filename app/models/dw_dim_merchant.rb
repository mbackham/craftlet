class DwDimMerchant < ApplicationRecord
  MERCHANT_TIERS = %w[standard silver gold platinum].freeze

  scope :by_tier, ->(tier) { where(merchant_tier: tier) }
  scope :active, -> { where(status: 'approved') }

  def self.ransackable_attributes(auth_object = nil)
    %w[source_merchant_id source_user_id shop_name status province city
       total_order_count total_gmv avg_order_amount refund_rate settlement_count
       total_settled_amount risk_event_count merchant_tier merchant_score
       profile_updated_at created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end
end
