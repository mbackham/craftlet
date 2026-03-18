# frozen_string_literal: true

module Bi
  # Returns time-series trend data for GMV, orders, refunds, net income.
  # Usage: Bi::TrendService.call(start_date: 30.days.ago.to_date, end_date: Date.today, group_by: :day)
  class TrendService
    GROUPINGS = %i[day week month].freeze

    DayPoint = Struct.new(:date, :gmv, :order_count, :refund_amount, :net_income, keyword_init: true)

    Result = Struct.new(:start_date, :end_date, :group_by, :points, :summary, keyword_init: true)

    Summary = Struct.new(:total_gmv, :total_orders, :total_refunds, :total_net, :avg_daily_gmv, keyword_init: true)

    def self.call(start_date: 30.days.ago.to_date, end_date: Date.today, group_by: :day)
      new(start_date, end_date, group_by).call
    end

    def initialize(start_date, end_date, group_by)
      @start_date = start_date
      @end_date   = end_date
      @group_by   = GROUPINGS.include?(group_by.to_sym) ? group_by.to_sym : :day
    end

    def call
      points = build_points
      Result.new(
        start_date: @start_date,
        end_date:   @end_date,
        group_by:   @group_by,
        points:     points,
        summary:    build_summary(points)
      )
    end

    private

    def build_points
      range = @start_date..@end_date
      paid_statuses = %w[paid accepted producing delivered completed refunded]

      # Fetch grouped data
      gmv_data    = Order.where(status: paid_statuses, created_at: range.first.beginning_of_day..range.last.end_of_day)
                         .group(group_expr(:created_at))
                         .sum(:total_amount)

      order_data  = Order.where(created_at: range.first.beginning_of_day..range.last.end_of_day)
                         .group(group_expr(:created_at))
                         .count

      refund_data = Refund.where(status: "succeeded", succeeded_at: range.first.beginning_of_day..range.last.end_of_day)
                          .group(group_expr(:succeeded_at))
                          .sum(:amount)

      # Build points for each date bucket
      date_keys(range).map do |key|
        date_str = key.to_s
        gmv      = gmv_data[date_str] || gmv_data[key] || 0
        orders_c = order_data[date_str] || order_data[key] || 0
        refund_a = refund_data[date_str] || refund_data[key] || 0

        DayPoint.new(
          date:          key,
          gmv:           gmv,
          order_count:   orders_c,
          refund_amount: refund_a,
          net_income:    gmv - refund_a
        )
      end
    end

    def build_summary(points)
      total_gmv     = points.sum(&:gmv)
      total_orders  = points.sum(&:order_count)
      total_refunds = points.sum(&:refund_amount)
      days          = [(@end_date - @start_date).to_i + 1, 1].max

      Summary.new(
        total_gmv:     total_gmv,
        total_orders:  total_orders,
        total_refunds: total_refunds,
        total_net:     total_gmv - total_refunds,
        avg_daily_gmv: (total_gmv.to_f / days).round(2)
      )
    end

    def group_expr(column)
      case @group_by
      when :day
        Arel.sql("DATE(#{column})")
      when :week
        Arel.sql("DATE_TRUNC('week', #{column})::date")
      when :month
        Arel.sql("DATE_TRUNC('month', #{column})::date")
      end
    end

    def date_keys(range)
      case @group_by
      when :day
        range.to_a
      when :week
        keys = []
        d = range.first.beginning_of_week
        while d <= range.last
          keys << d
          d += 7.days
        end
        keys
      when :month
        keys = []
        d = range.first.beginning_of_month
        while d <= range.last
          keys << d
          d = d.next_month
        end
        keys
      end
    end
  end
end
