module Etl
  class ProfileRebuildJob < ApplicationJob
    queue_as :etl

    def perform(target = 'all')
      case target
      when 'users', 'all'
        Rails.logger.info("[ETL][ProfileRebuildJob] Rebuilding user profiles")
        count = Etl::Profiles::UserProfileBuilder.call
        Rails.logger.info("[ETL][ProfileRebuildJob] User profiles rebuilt: #{count}")
      end

      case target
      when 'merchants', 'all'
        Rails.logger.info("[ETL][ProfileRebuildJob] Rebuilding merchant profiles")
        count = Etl::Profiles::MerchantProfileBuilder.call
        Rails.logger.info("[ETL][ProfileRebuildJob] Merchant profiles rebuilt: #{count}")
      end
    rescue => e
      Rails.logger.error("[ETL][ProfileRebuildJob] Failed: #{e.message}")
      raise
    end
  end
end
