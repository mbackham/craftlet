module Etl
  module Profiles
    class MerchantScorer
      # Weights for merchant score (0-100)
      WEIGHTS = {
        gmv:         0.35,
        order_count: 0.20,
        refund_rate: 0.20,  # inverse: lower refund rate = higher score
        settlements: 0.15,
        risk:        0.10   # inverse: fewer risk events = higher score
      }.freeze

      TIERS = [
        { tier: 'platinum', min_score: 80 },
        { tier: 'gold',     min_score: 60 },
        { tier: 'silver',   min_score: 40 },
        { tier: 'standard', min_score: 0  }
      ].freeze

      def initialize(all_stats)
        @all_stats = all_stats
        precompute_maxes
      end

      def score_and_tier(merchant_stat)
        score = compute_score(merchant_stat).round(2)
        tier  = TIERS.find { |t| score >= t[:min_score] }&.dig(:tier) || 'standard'
        [score, tier]
      end

      private

      def precompute_maxes
        @max_gmv    = @all_stats.map { |s| s[:total_gmv].to_f }.max || 1
        @max_orders = @all_stats.map { |s| s[:total_order_count].to_i }.max || 1
        @max_settle = @all_stats.map { |s| s[:settlement_count].to_i }.max || 1
        @max_risk   = @all_stats.map { |s| s[:risk_event_count].to_i }.max || 1
      end

      def compute_score(s)
        gmv_score    = normalize(s[:total_gmv].to_f, @max_gmv)
        order_score  = normalize(s[:total_order_count].to_i, @max_orders)
        refund_score = 100 - [s[:refund_rate].to_f, 100].min  # invert
        settle_score = normalize(s[:settlement_count].to_i, @max_settle)
        risk_score   = @max_risk > 0 ? 100 - normalize(s[:risk_event_count].to_i, @max_risk) : 100

        gmv_score    * WEIGHTS[:gmv] +
          order_score  * WEIGHTS[:order_count] +
          refund_score * WEIGHTS[:refund_rate] +
          settle_score * WEIGHTS[:settlements] +
          risk_score   * WEIGHTS[:risk]
      end

      def normalize(value, max)
        max.zero? ? 0 : [(value.to_f / max * 100), 100].min
      end
    end
  end
end
