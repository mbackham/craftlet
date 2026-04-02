module Etl
  class BaseLoader
    def initialize(target_model:)
      @target_model = target_model
    end

    # Upserts records into the target table, returns count loaded
    def load(records)
      return 0 if records.empty?

      @target_model.upsert_all(
        records,
        unique_by: :source_id,
        update_only: records.first.keys - ['source_id']
      )

      records.size
    rescue => e
      Rails.logger.error("[ETL][#{@target_model}] Load failed: #{e.message}")
      raise
    end
  end
end
