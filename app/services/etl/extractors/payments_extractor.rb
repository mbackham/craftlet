module Etl
  module Extractors
    class PaymentsExtractor < BaseExtractor
      private

      def source_model
        Payment
      end

      def transform(record)
        {
          source_id:      record.id,
          order_source_id: record.order_id,
          channel:        record.channel,
          amount:         record.amount,
          status:         record.status,
          paid_at:        record.paid_at,
          synced_at:      Time.current,
          etl_batch_id:   sync_log.batch_id,
          created_at:     record.created_at,
          updated_at:     Time.current
        }
      end

      public

      def extract_and_transform
        extract.map { |r| transform(r) }
      end
    end
  end
end
