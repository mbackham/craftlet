# frozen_string_literal: true

module Settlements
  class FreezeService
    attr_reader :settlement, :admin_user, :reason, :request, :error

    def initialize(settlement:, admin_user:, reason:, request: nil)
      @settlement = settlement
      @admin_user = admin_user
      @reason = reason
      @request = request
    end

    def call
      unless settlement.may_freeze_settlement?
        @error = "当前状态(#{settlement.status})不允许冻结"
        return self
      end

      if reason.blank?
        @error = "冻结原因不能为空"
        return self
      end

      ActiveRecord::Base.transaction do
        settlement.frozen_reason = reason
        settlement.freeze_settlement!

        # 同时创建异常记录
        settlement.settlement_exceptions.create!(
          exception_type: "merchant_frozen",
          description: reason,
          status: "pending"
        )

        AuditService.log!(
          action: "freeze_settlement",
          actor: admin_user,
          target: settlement,
          metadata: { reason: reason },
          request: request
        )
      end

      self
    rescue StandardError => e
      @error = e.message
      self
    end

    def success?
      @error.nil?
    end
  end
end
