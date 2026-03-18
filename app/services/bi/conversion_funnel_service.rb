# frozen_string_literal: true

module Bi
  # Order lifecycle conversion funnel.
  # Shows how many orders reached each stage and the conversion rate between stages.
  class ConversionFunnelService
    STAGES = %w[created paid accepted producing delivered completed].freeze

    Stage = Struct.new(:name, :count, :rate, keyword_init: true)

    Result = Struct.new(:stages, :canceled_count, :canceled_rate, :refunded_count, :refunded_rate, keyword_init: true)

    def self.call(start_date: nil, end_date: nil)
      new(start_date, end_date).call
    end

    def initialize(start_date, end_date)
      @range = if start_date && end_date
                 start_date.to_date.beginning_of_day..end_date.to_date.end_of_day
               end
    end

    def call
      base = @range ? Order.where(created_at: @range) : Order.all
      total = base.count
      return empty_result if total.zero?

      status_counts = base.group(:status).count

      # Each stage counts orders currently at or past that stage in the normal flow.
      # "canceled" and "refunded" are terminal but don't count towards later stages.
      stage_data = STAGES.map.with_index do |stage, idx|
        count = if idx == 0
                  total # all orders were created
                else
                  # Count orders at this stage or any later normal stage
                  base.where(status: STAGES[idx..]).count
                end

        rate = (count.to_f / total * 100).round(2)
        Stage.new(name: stage, count: count, rate: rate)
      end

      canceled_count  = status_counts.fetch("canceled", 0)
      refunded_count  = status_counts.fetch("refunded", 0)

      Result.new(
        stages:         stage_data,
        canceled_count: canceled_count,
        canceled_rate:  (canceled_count.to_f / total * 100).round(2),
        refunded_count: refunded_count,
        refunded_rate:  (refunded_count.to_f / total * 100).round(2)
      )
    end

    private

    def can_reach_from?(stage, target_status)
      stage_idx = STAGES.index(stage) || 0
      case target_status
      when "canceled" then stage_idx <= 2
      when "refunded" then stage_idx >= 1
      else false
      end
    end

    def empty_result
      stages = STAGES.map { |s| Stage.new(name: s, count: 0, rate: 0.0) }
      Result.new(stages: stages, canceled_count: 0, canceled_rate: 0.0, refunded_count: 0, refunded_rate: 0.0)
    end
  end
end
