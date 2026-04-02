module Etl
  module Profiles
    class UserProfileBuilder
      def self.call(user_ids: nil)
        new(user_ids: user_ids).build
      end

      def initialize(user_ids: nil)
        @user_ids = user_ids
      end

      def build
        scope = @user_ids ? DwDimUser.where(source_user_id: @user_ids) : DwDimUser.all
        users = scope.to_a

        return 0 if users.empty?

        # Aggregate stats per user from fact tables
        stats = compute_stats(users.map(&:source_user_id))

        # Compute RFM with population-level quantiles
        rfm_calc = RfmCalculator.new(stats.values)

        now = Time.current
        updates = users.map do |user|
          s = stats[user.source_user_id] || empty_stats
          rfm_seg = rfm_calc.segment_for(s)

          {
            source_user_id:       user.source_user_id,
            total_order_count:    s[:total_order_count],
            total_order_amount:   s[:total_order_amount],
            avg_order_amount:     s[:avg_order_amount],
            refund_count:         s[:refund_count],
            refund_rate:          s[:refund_rate],
            coupon_used_count:    s[:coupon_used_count],
            coupon_total_discount: s[:coupon_total_discount],
            first_order_at:       s[:first_order_at],
            last_order_at:        s[:last_order_at],
            days_since_last_order: s[:days_since_last_order],
            rfm_segment:          rfm_seg,
            profile_updated_at:   now,
            updated_at:           now
          }
        end

        DwDimUser.upsert_all(updates, unique_by: :source_user_id, update_only: updates.first.keys.map(&:to_s) - ['source_user_id'])
        updates.size
      end

      private

      def compute_stats(user_ids)
        # Order stats from dw_fact_orders (customer_id is UUID string)
        order_stats = DwFactOrder.where(customer_id: user_ids.map(&:to_s))
          .group(:customer_id)
          .select(
            :customer_id,
            'COUNT(*) AS order_count',
            'SUM(total_amount) AS total_amount',
            'AVG(total_amount) AS avg_amount',
            'MIN(paid_at) AS first_order',
            'MAX(paid_at) AS last_order'
          )

        # Refund stats
        refund_stats = DwFactRefund
          .joins("JOIN dw_fact_orders ON dw_fact_orders.source_id = dw_fact_refunds.order_source_id")
          .where("dw_fact_orders.customer_id IN (?)", user_ids.map(&:to_s))
          .group("dw_fact_orders.customer_id")
          .select("dw_fact_orders.customer_id, COUNT(*) AS refund_count")

        # Coupon stats
        coupon_stats = DwFactCoupon.where(user_id: user_ids)
          .group(:user_id)
          .select('user_id, COUNT(*) AS coupon_count, SUM(discount_amount) AS total_discount')

        # Build lookup maps
        order_map  = order_stats.index_by { |r| r.customer_id.to_i }
        refund_map = refund_stats.index_by { |r| r.customer_id.to_i }
        coupon_map = coupon_stats.index_by(&:user_id)

        today = Date.today

        user_ids.each_with_object({}) do |uid, hash|
          o = order_map[uid]
          r = refund_map[uid]
          c = coupon_map[uid]

          total_orders  = o&.order_count.to_i
          total_amount  = o&.total_amount.to_f
          refund_count  = r&.refund_count.to_i
          last_order_at = o&.last_order

          days_since = last_order_at ? (today - last_order_at.to_date).to_i : nil

          hash[uid] = {
            total_order_count:    total_orders,
            total_order_amount:   total_amount,
            avg_order_amount:     total_orders > 0 ? (total_amount / total_orders).round(2) : 0,
            refund_count:         refund_count,
            refund_rate:          total_orders > 0 ? ((refund_count.to_f / total_orders) * 100).round(2) : 0,
            coupon_used_count:    c&.coupon_count.to_i,
            coupon_total_discount: c&.total_discount.to_f,
            first_order_at:       o&.first_order,
            last_order_at:        last_order_at,
            days_since_last_order: days_since
          }
        end
      end

      def empty_stats
        {
          total_order_count: 0, total_order_amount: 0, avg_order_amount: 0,
          refund_count: 0, refund_rate: 0, coupon_used_count: 0,
          coupon_total_discount: 0, first_order_at: nil, last_order_at: nil,
          days_since_last_order: nil
        }
      end
    end
  end
end
