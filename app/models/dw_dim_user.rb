class DwDimUser < ApplicationRecord
  RFM_SEGMENTS = %w[champion loyal_customer potential_loyalist new_customer promising need_attention at_risk lost].freeze
  USER_LEVELS = %w[normal vip premium].freeze

  scope :by_segment, ->(seg) { where(rfm_segment: seg) }
  scope :by_level, ->(lvl) { where(user_level: lvl) }
  scope :active, -> { where(status: 'active') }

  def self.ransackable_attributes(auth_object = nil)
    %w[source_user_id email phone nickname status user_level rfm_segment total_order_count
       total_order_amount avg_order_amount refund_rate coupon_used_count first_order_at last_order_at
       days_since_last_order profile_updated_at created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end
end
