# frozen_string_literal: true

module Settlements
  class GenerateService
    attr_reader :date, :errors, :generated_settlements

    def initialize(date: Date.yesterday)
      @date = date
      @errors = []
      @generated_settlements = []
    end

    def call
      active_merchants = MerchantProfile.approved

      active_merchants.find_each do |merchant|
        rule = SettlementRule.rule_for(merchant)
        next unless rule

        generate_for_merchant(merchant, rule)
      rescue StandardError => e
        @errors << "商家 #{merchant.shop_name}(ID:#{merchant.id}) 结算失败: #{e.message}"
        Rails.logger.error("Settlement generation failed for merchant #{merchant.id}: #{e.message}")
      end

      self
    end

    def success?
      @errors.empty?
    end

    private

    def generate_for_merchant(merchant, rule)
      period_end = date
      period_start = period_end - rule.cycle_days.days + 1.day

      # 检查是否已有该周期的结算单
      return if Settlement.exists?(
        merchant_profile_id: merchant.id,
        period_start: period_start,
        period_end: period_end
      )

      # 查找周期内已完成的订单（通过 merchant_id UUID 关联）
      merchant_uuid = MerchantProfile.format_admin_id_as_uuid(merchant.user_id)
      completed_orders = Order.where(merchant_id: merchant_uuid, status: "completed")
                              .where(completed_at: period_start.beginning_of_day..period_end.end_of_day)

      return if completed_orders.empty?

      ActiveRecord::Base.transaction do
        settlement = Settlement.create!(
          merchant_profile: merchant,
          period_start: period_start,
          period_end: period_end,
          total_order_amount: 0,
          total_refund_amount: 0,
          net_amount: 0
        )

        completed_orders.find_each do |order|
          order_refunds = order.refunds.where(status: "succeeded").sum(:amount)

          settlement.settlement_items.create!(
            order: order,
            order_amount: order.total_amount,
            refund_amount: order_refunds,
            net_amount: [order.total_amount - order_refunds, 0].max
          )
        end

        settlement.calculate_amounts!

        # 如果净额低于最低结算金额，跳过
        if settlement.net_amount < rule.min_settlement_amount
          settlement.destroy!
          return
        end

        @generated_settlements << settlement

        AuditService.log!(
          action: "generate_settlement",
          target: settlement,
          metadata: {
            merchant_id: merchant.id,
            period: "#{period_start} ~ #{period_end}",
            net_amount: settlement.net_amount.to_f,
            items_count: settlement.settlement_items.count
          }
        )
      end
    end
  end
end
