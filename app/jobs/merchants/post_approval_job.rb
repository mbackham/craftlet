# frozen_string_literal: true

module Merchants
  class PostApprovalJob < ApplicationJob
    queue_as :default

    def perform(merchant_profile_id)
      merchant_profile = MerchantProfile.find_by(id: merchant_profile_id)
      return unless merchant_profile

      Rails.logger.info "[Merchants::PostApprovalJob] Processing merchant #{merchant_profile.id}"

      # TODO: 实现审批后异步任务
      # - 发送通知邮件/短信
      # - 创建商家初始化数据
      # - 同步到第三方系统

      Rails.logger.info "[Merchants::PostApprovalJob] Completed for merchant #{merchant_profile.id}"
    end
  end
end
