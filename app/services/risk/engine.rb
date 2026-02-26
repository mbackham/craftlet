# frozen_string_literal: true

module Risk
  # Risk::Engine — 风控规则引擎
  #
  # 在业务触发点调用，检测是否命中已启用的风控规则，
  # 命中则写入 RiskEvent 供运营后台处理。
  #
  # 用法:
  #   Risk::Engine.check(:refund_create, user_uuid: user_uuid, refund: refund)
  #   Risk::Engine.check(:bid_create, user_uuid: merchant_uuid, bid: bid)
  class Engine
    # 注册的规则检测器 (code => lambda)
    RULES = {
      # --- 规则 1: 同一用户短时高频退款申请 ---
      "high_freq_refund" => -> (ctx) {
        user_id = ctx[:user_uuid]
        return nil unless user_id

        rule = RiskRule.enabled.find_by(code: "high_freq_refund")
        return nil unless rule

        window  = (rule.params["window_minutes"] || 60).to_i.minutes
        threshold = (rule.params["threshold"] || 3).to_i

        recent_count = Refund.joins(:order)
                             .where(orders: { customer_id: user_id })
                             .where("refunds.created_at > ?", window.ago)
                             .count

        if recent_count >= threshold
          {
            rule: rule,
            context: {
              user_uuid:    user_id,
              recent_count: recent_count,
              threshold:    threshold,
              window_minutes: window / 60
            }
          }
        end
      },

      # --- 规则 2: 同一用户高金额退款 ---
      "high_amount_refund" => -> (ctx) {
        user_id = ctx[:user_uuid]
        refund  = ctx[:refund]
        return nil unless user_id && refund

        rule = RiskRule.enabled.find_by(code: "high_amount_refund")
        return nil unless rule

        amount_threshold = (rule.params["amount_threshold"] || 1000).to_f

        if refund.amount >= amount_threshold
          {
            rule: rule,
            context: {
              user_uuid:        user_id,
              refund_id:        refund.id,
              refund_amount:    refund.amount.to_f,
              amount_threshold: amount_threshold
            }
          }
        end
      },

      # --- 规则 3: 同一商家短时大量竞标/撤回 ---
      "merchant_bid_spam" => -> (ctx) {
        user_id = ctx[:user_uuid]
        return nil unless user_id

        rule = RiskRule.enabled.find_by(code: "merchant_bid_spam")
        return nil unless rule

        window    = (rule.params["window_minutes"] || 30).to_i.minutes
        threshold = (rule.params["threshold"] || 10).to_i

        recent_count = Bid.where(bidder_id: user_id)
                          .where("created_at > ?", window.ago)
                          .count

        if recent_count >= threshold
          {
            rule: rule,
            context: {
              user_uuid:      user_id,
              recent_count:   recent_count,
              threshold:      threshold,
              window_minutes: window / 60
            }
          }
        end
      }
    }.freeze

    # 主入口：检查指定触发点的所有已启用规则
    # @param trigger_source [Symbol] 触发来源 (:refund_create, :bid_create 等)
    # @param ctx [Hash] 上下文数据
    # @return [Array<RiskEvent>] 产生的风控事件列表
    def self.check(trigger_source, **ctx)
      events = []

      rules_for(trigger_source).each do |code|
        detector = RULES[code]
        next unless detector

        begin
          hit = detector.call(ctx)
          next unless hit

          event = RiskEvent.create!(
            risk_rule:      hit[:rule],
            status:         "pending",
            subject_id:     ctx[:user_uuid],
            subject_type:   ctx[:subject_type] || "User",
            trigger_source: trigger_source.to_s,
            context:        hit[:context] || {}
          )
          events << event

          Rails.logger.warn("[Risk::Engine] Rule #{code} triggered for #{ctx[:user_uuid]} — event ##{event.id}")
        rescue => e
          Rails.logger.error("[Risk::Engine] Error checking rule #{code}: #{e.message}")
        end
      end

      events
    end

    private

    # 每个触发源关联的规则列表
    TRIGGER_RULES = {
      refund_create: %w[high_freq_refund high_amount_refund],
      bid_create:    %w[merchant_bid_spam]
    }.freeze

    def self.rules_for(trigger_source)
      TRIGGER_RULES[trigger_source.to_sym] || []
    end
  end
end
