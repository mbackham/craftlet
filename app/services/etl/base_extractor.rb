module Etl
  class BaseExtractor
    BATCH_SIZE = 500

    attr_reader :sync_log

    def initialize(sync_log:)
      @sync_log = sync_log
    end

    # Returns an array of raw source records (ActiveRecord objects)
    def extract
      cursor = last_cursor
      records = []

      source_scope(cursor).find_in_batches(batch_size: BATCH_SIZE) do |batch|
        records.concat(batch)
      end

      records
    end

    private

    # Subclasses must implement: source model, target table, cursor field
    def source_model
      raise NotImplementedError, "#{self.class} must implement #source_model"
    end

    def cursor_field
      :updated_at
    end

    def last_cursor
      last_log = EtlSyncLog.where(
        source_table: source_table_name,
        status: 'completed'
      ).order(completed_at: :desc).first

      last_log&.metadata&.dig('cursor') || 30.days.ago
    end

    def source_table_name
      source_model.table_name
    end

    def source_scope(cursor)
      source_model.where("#{cursor_field} > ?", cursor).order(cursor_field => :asc)
    end
  end
end
