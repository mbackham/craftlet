module Etl
  class SyncJob < ApplicationJob
    queue_as :etl

    def perform(source, sync_type = 'incremental')
      Rails.logger.info("[ETL][SyncJob] Starting sync for source=#{source} type=#{sync_type}")
      Etl::Pipeline.call(source: source, sync_type: sync_type)
    rescue => e
      Rails.logger.error("[ETL][SyncJob] Failed: #{e.message}")
      raise
    end
  end
end
