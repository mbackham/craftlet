# frozen_string_literal: true

module Bi
  # Refund analysis: rate, reason breakdown, top refund merchants.
  # Usage: Bi::RefundAnalysisService.call(start_date: 30.days.ago.to_date, end_date: Date.today)
  class RefundAnalysisService
    ReasonBreakdown = Struct.new(:reason, :count, :amount, :percentage, keyword_init: true)

    TopRefundMerchant = Struct.new(:merchant_profile_id, :shop_name, :refund_count, :refund_amount, :refund_rate, keyword_init: true)

    Result = Struct.new(
      :total_refund_count,
      :total_refund_amount,
      :refund_rate,            # refund_amount / gmv * 100
      :avg_refund_amount,
      :reason_breakdown,       # Array of ReasonBreakdown
      :top_refund_merchants,   # Array of TopRefundMerchant
      keyword_init: true
    )

    def self.call(start_date: 30.days.ago.to_date, end_date: Date.today, merchant_limit: 5)
      new(start_date, end_date, merchant_limit).call
    end

    def initialize(start_date, end_date, merchant_limit)
      @range = start_date.to_date.beginning_of_day..end_date.to_date.end_of_day
      @merchant_limit = merchant_limit
    end

    def call
      refunds = Refund.where(status: "succeeded", succeeded_at: @range)
      total_count  = refunds.count
      total_amount = refunds.sum(:amount)

      paid_statuses = %w[paid accepted producing delivered completed refunded]
      gmv = Order.where(status: paid_statuses, created_at: @range).sum(:total_amount)

      Result.new(
        total_refund_count:  total_count,
        total_refund_amount: total_amount,
        refund_rate:         gmv > 0 ? (total_amount / gmv * 100).round(2) : 0.0,
        avg_refund_amount:   total_count > 0 ? (total_amount / total_count).round(2) : 0.0,
        reason_breakdown:    build_reason_breakdown(refunds, total_count),
        top_refund_merchants: build_top_merchants
      )
    end

    private

    def build_reason_breakdown(refunds, total_count)
      grouped = refunds.group(:reason).count
      amounts = refunds.group(:reason).sum(:amount)

      grouped.map do |reason, count|
        ReasonBreakdown.new(
          reason:     reason.presence || "unspecified",
          count:      count,
          amount:     amounts[reason] || 0,
          percentage: total_count > 0 ? (count.to_f / total_count * 100).round(2) : 0.0
        )
      end.sort_by { |r| -r.count }
    end

    def build_top_merchants
      # Join refunds → orders to get merchant_id, then aggregate
      merchant_refunds = Refund.joins(:order)
                               .where(status: "succeeded", succeeded_at: @range)
                               .group("orders.merchant_id")
                               .select(
                                 "orders.merchant_id",
                                 "COUNT(refunds.id) as refund_count",
                                 "SUM(refunds.amount) as refund_amount"
                               )

      paid_statuses = %w[paid accepted producing delivered completed refunded]

      merchant_refunds.map do |mr|
        merchant_uuid = mr.merchant_id
        next unless merchant_uuid

        user_id = merchant_uuid.to_s.split("-").last.to_i
        user = User.find_by(id: user_id)
        profile = user&.merchant_profile
        next unless profile

        merchant_gmv = Order.where(merchant_id: merchant_uuid, status: paid_statuses, created_at: @range)
                            .sum(:total_amount)

        TopRefundMerchant.new(
          merchant_profile_id: profile.id,
          shop_name:           profile.shop_name,
          refund_count:        mr.refund_count.to_i,
          refund_amount:       mr.refund_amount.to_f,
          refund_rate:         merchant_gmv > 0 ? (mr.refund_amount.to_f / merchant_gmv * 100).round(2) : 0.0
        )
      end.compact.sort_by { |m| -m.refund_amount }.first(@merchant_limit)
    end
  end
end
