# frozen_string_literal: true

module Refunds
  class ProcessRefundJob < ApplicationJob
    queue_as :default

    def perform(refund_id)
      refund = Refund.find_by(id: refund_id)
      return unless refund
      return unless refund.status == 'pending'

      Rails.logger.info "[Refunds::ProcessRefundJob] Processing refund #{refund.id}"

      # TODO: 下周实现真实退款逻辑
      # - 调用聚合支付 provider 接口
      # - 处理回调
      # - 更新退款状态

      # 模拟退款成功（下周替换为真实逻辑）
      # refund.update!(status: 'succeeded', succeeded_at: Time.current)

      Rails.logger.info "[Refunds::ProcessRefundJob] Completed for refund #{refund.id}"
    end
  end
end
