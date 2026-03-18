# frozen_string_literal: true

module Bi
  # Ranks merchants by various metrics: GMV, order count, refund rate.
  # Usage: Bi::MerchantRankingService.call(metric: :gmv, period: :month, limit: 10)
  class MerchantRankingService
    METRICS = %i[gmv order_count refund_rate].freeze

    RankedMerchant = Struct.new(
      :rank, :merchant_profile_id, :shop_name, :gmv,
      :order_count, :refund_amount, :refund_rate,
      keyword_init: true
    )

    def self.call(metric: :gmv, period: :month, limit: 10)
      new(metric, period, limit).call
    end

    def initialize(metric, period, limit)
      @metric = METRICS.include?(metric.to_sym) ? metric.to_sym : :gmv
      @limit  = [limit.to_i, 1].max
      @duration = Bi::OverviewService::PERIODS.fetch(period.to_sym, 30.days)
      @range = @duration.ago..Time.current
    end

    def call
      merchants = build_merchant_data
      sorted    = sort_merchants(merchants)
      sorted.first(@limit).each_with_index.map do |m, idx|
        m.rank = idx + 1
        m
      end
    end

    private

    def build_merchant_data
      paid_statuses = %w[paid accepted producing delivered completed refunded]
      time_range    = @range.first.beginning_of_day..@range.last

      # merchant_id is UUID on orders; we need to link through MerchantProfile → User
      profiles = MerchantProfile.approved.includes(:user)
      profiles.map do |profile|
        user = profile.user
        next unless user

        merchant_uuid = user_uuid(user.id)
        orders = Order.where(merchant_id: merchant_uuid, created_at: time_range)
        paid_orders = orders.where(status: paid_statuses)
        gmv = paid_orders.sum(:total_amount)
        refund_amt = Refund.joins(:order)
                           .where(orders: { merchant_id: merchant_uuid })
                           .where(status: "succeeded", succeeded_at: time_range)
                           .sum(:amount)

        RankedMerchant.new(
          rank:                0,
          merchant_profile_id: profile.id,
          shop_name:           profile.shop_name,
          gmv:                 gmv,
          order_count:         paid_orders.count,
          refund_amount:       refund_amt,
          refund_rate:         gmv > 0 ? (refund_amt / gmv * 100).round(2) : 0.0
        )
      end.compact
    end

    def sort_merchants(merchants)
      case @metric
      when :gmv
        merchants.sort_by { |m| -m.gmv }
      when :order_count
        merchants.sort_by { |m| -m.order_count }
      when :refund_rate
        merchants.sort_by { |m| -m.refund_rate }
      end
    end

    def user_uuid(user_id)
      format("00000000-0000-0000-0000-%012d", user_id.to_i)
    end
  end
end
