# frozen_string_literal: true

module Bi
  # Aggregates core KPIs from existing tables.
  # Usage: Bi::OverviewService.call(period: :month)
  class OverviewService
    PERIODS = { week: 7.days, month: 30.days, quarter: 90.days, year: 365.days }.freeze

    Result = Struct.new(
      :gmv,                  # 成交总额
      :order_count,          # 订单总数
      :paid_order_count,     # 已支付订单数
      :user_count,           # 注册用户数
      :merchant_count,       # 审核通过商家数
      :payment_success_rate, # 支付成功率 (%)
      :refund_rate,          # 退款率 (%)
      :avg_order_value,      # 平均客单价
      :total_refund,         # 退款总额
      :net_income,           # 净收入 = GMV - 退款
      :settled_amount,       # 已结算金额
      :gmv_growth,           # GMV 环比增长率 (%)
      :order_growth,         # 订单环比增长率 (%)
      keyword_init: true
    )

    def self.call(period: :month)
      new(period).call
    end

    def initialize(period)
      @duration = PERIODS.fetch(period.to_sym, 30.days)
      @current_range = @duration.ago..Time.current
      @previous_range = (@duration * 2).ago..@duration.ago
    end

    def call
      current  = compute_metrics(@current_range)
      previous = compute_metrics(@previous_range)

      Result.new(
        gmv:                  current[:gmv],
        order_count:          current[:order_count],
        paid_order_count:     current[:paid_order_count],
        user_count:           User.count,
        merchant_count:       MerchantProfile.approved.count,
        payment_success_rate: payment_success_rate,
        refund_rate:          current[:gmv] > 0 ? (current[:refund_total] / current[:gmv] * 100).round(2) : 0.0,
        avg_order_value:      current[:paid_order_count] > 0 ? (current[:gmv] / current[:paid_order_count]).round(2) : 0.0,
        total_refund:         current[:refund_total],
        net_income:           current[:gmv] - current[:refund_total],
        settled_amount:       Settlement.where(status: "confirmed", confirmed_at: @current_range).sum(:net_amount),
        gmv_growth:           growth_rate(previous[:gmv], current[:gmv]),
        order_growth:         growth_rate(previous[:order_count], current[:order_count])
      )
    end

    private

    def compute_metrics(range)
      paid_statuses = %w[paid accepted producing delivered completed refunded]
      orders   = Order.where(status: paid_statuses, created_at: range)
      gmv      = orders.sum(:total_amount)
      refund_t = Refund.where(status: "succeeded", succeeded_at: range).sum(:amount)

      {
        gmv:              gmv,
        order_count:      Order.where(created_at: range).count,
        paid_order_count: orders.count,
        refund_total:     refund_t
      }
    end

    def payment_success_rate
      total   = Payment.where(created_at: @current_range).count
      success = Payment.where(status: "paid", created_at: @current_range).count
      total > 0 ? (success.to_f / total * 100).round(2) : 0.0
    end

    def growth_rate(old_val, new_val)
      return 0.0 if old_val.nil? || old_val.zero?
      ((new_val - old_val).to_f / old_val * 100).round(2)
    end
  end
end
