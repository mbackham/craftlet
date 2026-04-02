module Etl
  module Profiles
    class MerchantProfileBuilder
      def self.call(merchant_ids: nil)
        new(merchant_ids: merchant_ids).build
      end

      def initialize(merchant_ids: nil)
        @merchant_ids = merchant_ids
      end

      def build
        scope = @merchant_ids ? DwDimMerchant.where(source_merchant_id: @merchant_ids) : DwDimMerchant.all
        merchants = scope.to_a

        return 0 if merchants.empty?

        stats = compute_stats(merchants.map(&:source_merchant_id))
        scorer = MerchantScorer.new(stats.values)

        now = Time.current
        updates = merchants.map do |merchant|
          s = stats[merchant.source_merchant_id] || empty_stats
          score, tier = scorer.score_and_tier(s)

          {
            source_merchant_id:   merchant.source_merchant_id,
            total_order_count:    s[:total_order_count],
            total_gmv:            s[:total_gmv],
            avg_order_amount:     s[:avg_order_amount],
            refund_count:         s[:refund_count],
            refund_rate:          s[:refund_rate],
            settlement_count:     s[:settlement_count],
            total_settled_amount: s[:total_settled_amount],
            risk_event_count:     s[:risk_event_count],
            merchant_score:       score,
            merchant_tier:        tier,
            profile_updated_at:   now,
            updated_at:           now
          }
        end

        DwDimMerchant.upsert_all(updates, unique_by: :source_merchant_id, update_only: updates.first.keys.map(&:to_s) - ['source_merchant_id'])
        updates.size
      end

      private

      def compute_stats(merchant_ids)
        # merchant_id in dw_fact_orders is UUID string; map from source_merchant_id via DwDimMerchant
        merchants = DwDimMerchant.where(source_merchant_id: merchant_ids).select(:source_merchant_id, :source_user_id)
        merchant_uuid_map = merchants.each_with_object({}) { |m, h| h[m.source_merchant_id] = m.source_user_id.to_s }

        order_stats = DwFactOrder.where(merchant_id: merchant_uuid_map.values)
          .group(:merchant_id)
          .select('merchant_id, COUNT(*) AS order_count, SUM(total_amount) AS gmv, AVG(total_amount) AS avg_amount')

        refund_stats = DwFactRefund
          .joins("JOIN dw_fact_orders ON dw_fact_orders.source_id = dw_fact_refunds.order_source_id")
          .where("dw_fact_orders.merchant_id IN (?)", merchant_uuid_map.values)
          .group("dw_fact_orders.merchant_id")
          .select("dw_fact_orders.merchant_id, COUNT(*) AS refund_count")

        settle_stats = DwFactSettlement.where(merchant_source_id: merchant_ids)
          .group(:merchant_source_id)
          .select('merchant_source_id, COUNT(*) AS settle_count, SUM(net_amount) AS settled_amount')

        risk_stats = RiskEvent.where(subject_type: 'User', subject_id: merchant_uuid_map.values)
          .group(:subject_id)
          .select('subject_id, COUNT(*) AS risk_count')

        # Build reverse maps
        uuid_to_mid = merchant_uuid_map.invert
        order_map  = order_stats.index_by { |r| uuid_to_mid[r.merchant_id] }
        refund_map = refund_stats.index_by { |r| uuid_to_mid[r.merchant_id] }
        settle_map = settle_stats.index_by(&:merchant_source_id)
        risk_map   = risk_stats.index_by { |r| uuid_to_mid[r.subject_id] }

        merchant_ids.each_with_object({}) do |mid, hash|
          o = order_map[mid]
          r = refund_map[mid]
          s = settle_map[mid]
          ri = risk_map[mid]

          total_orders = o&.order_count.to_i
          total_gmv    = o&.gmv.to_f
          refund_count = r&.refund_count.to_i

          hash[mid] = {
            total_order_count:    total_orders,
            total_gmv:            total_gmv,
            avg_order_amount:     total_orders > 0 ? (total_gmv / total_orders).round(2) : 0,
            refund_count:         refund_count,
            refund_rate:          total_orders > 0 ? ((refund_count.to_f / total_orders) * 100).round(2) : 0,
            settlement_count:     s&.settle_count.to_i,
            total_settled_amount: s&.settled_amount.to_f,
            risk_event_count:     ri&.risk_count.to_i
          }
        end
      end

      def empty_stats
        {
          total_order_count: 0, total_gmv: 0, avg_order_amount: 0,
          refund_count: 0, refund_rate: 0, settlement_count: 0,
          total_settled_amount: 0, risk_event_count: 0
        }
      end
    end
  end
end
