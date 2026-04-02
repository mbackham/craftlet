module Etl
  module Extractors
    class OrdersExtractor < BaseExtractor
      private

      def source_model
        Order
      end

      def transform(record)
        dim_time = DwDimTime.find_or_create_for(record.paid_at || record.created_at)

        {
          source_id:      record.id,
          order_no:       record.order_no,
          customer_id:    record.customer_id.to_s,
          merchant_id:    record.merchant_id.to_s,
          status:         record.status,
          total_amount:   record.total_amount,
          currency:       record.currency,
          paid_at:        record.paid_at,
          completed_at:   record.completed_at,
          canceled_at:    record.canceled_at,
          dim_time_id:    dim_time&.id,
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
