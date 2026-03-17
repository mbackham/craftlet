# frozen_string_literal: true

module Settlements
  class GenerateJob < ApplicationJob
    queue_as :default

    def perform(date: Date.yesterday)
      service = Settlements::GenerateService.new(date: date).call

      if service.success?
        Rails.logger.info("[Settlement] 成功生成 #{service.generated_settlements.size} 份结算单 (date=#{date})")
      else
        Rails.logger.error("[Settlement] 生成结算单有错误: #{service.errors.join(', ')}")
      end
    end
  end
end
