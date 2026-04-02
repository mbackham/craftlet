module Etl
  module Extractors
    class SettlementsExtractor < BaseExtractor
      private

      def source_model
        Settlement
      end

      def transform(record)
        {
          source_id:          record.id,
          merchant_source_id: record.merchant_profile_id,
          net_amount:         record.net_amount,
          status:             record.status,
          period_start:       record.period_start,
          period_end:         record.period_end,
          synced_at:          Time.current,
          etl_batch_id:       sync_log.batch_id,
          created_at:         record.created_at,
          updated_at:         Time.current
        }
      end

      public

      def extract_and_transform
        extract.map { |r| transform(r) }
      end
    end
  end
end
