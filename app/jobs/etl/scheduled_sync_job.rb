module Etl
  class ScheduledSyncJob < ApplicationJob
    queue_as :etl

    def perform
      Rails.logger.info("[ETL][ScheduledSyncJob] Running scheduled incremental sync")

      Etl::Pipeline.all_sources.each do |source|
        Etl::SyncJob.perform_later(source, 'incremental')
      end

      Rails.logger.info("[ETL][ScheduledSyncJob] Enqueued incremental sync jobs for all sources")
    end
  end
end
