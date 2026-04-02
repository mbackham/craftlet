module Etl
  module Extractors
    class UsersExtractor < BaseExtractor
      private

      def source_model
        User
      end

      def transform(record)
        {
          source_user_id: record.id,
          email:          record.email,
          phone:          record.phone,
          nickname:       record.nickname,
          status:         record.status,
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
