module Etl
  module Extractors
    class MerchantsExtractor < BaseExtractor
      private

      def source_model
        MerchantProfile
      end

      def transform(record)
        {
          source_merchant_id: record.id,
          source_user_id:     record.user_id,
          shop_name:          record.shop_name,
          status:             record.status,
          province:           record.address_province,
          city:               record.address_city,
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
