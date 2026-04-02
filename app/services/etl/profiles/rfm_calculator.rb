module Etl
  module Profiles
    class RfmCalculator
      # RFM segments based on score thresholds
      SEGMENTS = {
        'champion'           => ->(r, f, m) { r >= 4 && f >= 4 && m >= 4 },
        'loyal_customer'     => ->(r, f, m) { f >= 4 && m >= 3 },
        'potential_loyalist' => ->(r, f, m) { r >= 3 && f <= 3 },
        'new_customer'       => ->(r, f, m) { r >= 4 && f <= 1 },
        'promising'          => ->(r, f, m) { r >= 3 && f <= 2 && m <= 2 },
        'need_attention'     => ->(r, f, m) { r <= 3 && f >= 2 && m >= 2 },
        'at_risk'            => ->(r, f, m) { r <= 2 && f >= 3 && m >= 3 },
        'lost'               => ->(r, f, m) { r <= 1 }
      }.freeze

      def initialize(all_users_stats)
        @all_stats = all_users_stats
        precompute_quantiles
      end

      def segment_for(user_stat)
        r = score_recency(user_stat[:days_since_last_order])
        f = score_frequency(user_stat[:total_order_count])
        m = score_monetary(user_stat[:total_order_amount])

        SEGMENTS.find { |_seg, check| check.call(r, f, m) }&.first || 'need_attention'
      end

      private

      def precompute_quantiles
        recencies  = @all_stats.map { |s| s[:days_since_last_order].to_i }.sort
        freqs      = @all_stats.map { |s| s[:total_order_count].to_i }.sort
        monetaries = @all_stats.map { |s| s[:total_order_amount].to_f }.sort

        @r_quantiles = quantiles(recencies)
        @f_quantiles = quantiles(freqs)
        @m_quantiles = quantiles(monetaries)
      end

      def quantiles(sorted_arr)
        n = sorted_arr.size
        return [0, 0, 0, 0] if n.zero?

        [
          sorted_arr[(n * 0.25).ceil - 1],
          sorted_arr[(n * 0.5).ceil - 1],
          sorted_arr[(n * 0.75).ceil - 1],
          sorted_arr.last
        ]
      end

      # Lower days = higher recency score (more recent = better)
      def score_recency(days)
        return 5 if days.nil? || days == 0
        d = days.to_i
        if d <= @r_quantiles[0]
          5
        elsif d <= @r_quantiles[1]
          4
        elsif d <= @r_quantiles[2]
          3
        elsif d <= @r_quantiles[3]
          2
        else
          1
        end
      end

      def score_frequency(count)
        score_ascending(count.to_i, @f_quantiles)
      end

      def score_monetary(amount)
        score_ascending(amount.to_f, @m_quantiles)
      end

      def score_ascending(val, quantiles)
        if val >= quantiles[3]
          5
        elsif val >= quantiles[2]
          4
        elsif val >= quantiles[1]
          3
        elsif val >= quantiles[0]
          2
        else
          1
        end
      end
    end
  end
end
