# frozen_string_literal: true

module FundMonitoring
  # Aggregates daily fund data from Payment, Refund, and Settlement tables.
  # Returns a plain struct – no DB writes needed.
  class DailyReportService
    Result = Struct.new(
      :date,
      :income,          # 当日成功支付总额
      :income_count,    # 成功支付笔数
      :refund_total,    # 当日成功退款总额
      :refund_count,    # 成功退款笔数
      :settled,         # 当日已确认结算净额
      :net,             # income - refund_total
      :alert_count,     # 大额预警数量
      keyword_init: true
    )

    def self.call(date: Date.today)
      new(date).call
    end

    def initialize(date)
      @date  = date
      @range = date.beginning_of_day..date.end_of_day
    end

    def call
      payments  = Payment.where(status: "paid", paid_at: @range)
      refunds   = Refund.where(status: "succeeded", succeeded_at: @range)
      settled   = Settlement.where(status: "confirmed", confirmed_at: @range).sum(:net_amount)
      alerts    = FundAlert.where(created_at: @range).count

      income       = payments.sum(:amount)
      refund_total = refunds.sum(:amount)

      Result.new(
        date:          @date,
        income:        income,
        income_count:  payments.count,
        refund_total:  refund_total,
        refund_count:  refunds.count,
        settled:       settled,
        net:           income - refund_total,
        alert_count:   alerts
      )
    end
  end
end
