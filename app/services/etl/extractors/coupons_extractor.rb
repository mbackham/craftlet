module Etl
  module Extractors
    class CouponsExtractor < BaseExtractor
      private

      def source_model
        Coupon
      end

      def source_scope(cursor)
        # Only extract used coupons
        source_model.where("updated_at > ? AND status = ?", cursor, 'used').order(updated_at: :asc)
      end

      def transform(record)
        {
          source_id:       record.id,
          user_id:         record.user_id,
          template_id:     record.coupon_template_id,
          discount_amount: record.discount_amount,
          used_at:         record.used_at,
          synced_at:       Time.current,
          etl_batch_id:    sync_log.batch_id,
          created_at:      record.created_at,
          updated_at:      Time.current
        }
      end

      public

      def extract_and_transform
        extract.map { |r| transform(r) }
      end
    end
  end
end
