module Etl
  class FullSyncJob < ApplicationJob
    queue_as :etl

    # Dependency order: dimensions first, then facts
    SYNC_ORDER = %w[users merchant_profiles orders payments refunds settlements coupons].freeze

    def perform
      Rails.logger.info("[ETL][FullSyncJob] Starting full sync for all sources")

      SYNC_ORDER.each do |source|
        begin
          Etl::Pipeline.call(source: source, sync_type: 'full')
          Rails.logger.info("[ETL][FullSyncJob] Completed sync for #{source}")
        rescue => e
          Rails.logger.error("[ETL][FullSyncJob] Failed for #{source}: #{e.message}")
          # Continue with remaining sources even if one fails
        end
      end

      Rails.logger.info("[ETL][FullSyncJob] Full sync completed")
    end
  end
end
