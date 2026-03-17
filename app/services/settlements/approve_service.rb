# frozen_string_literal: true

module Settlements
  class ApproveService
    attr_reader :settlement, :admin_user, :comment, :request, :error

    def initialize(settlement:, admin_user:, comment: nil, request: nil)
      @settlement = settlement
      @admin_user = admin_user
      @comment = comment
      @request = request
    end

    def call
      unless settlement.may_approve?
        @error = "当前状态(#{settlement.status})不允许审批"
        return self
      end

      ActiveRecord::Base.transaction do
        settlement.approved_by = admin_user.id
        settlement.approved_at = Time.current
        settlement.approve!

        AuditService.log!(
          action: "approve_settlement",
          actor: admin_user,
          target: settlement,
          metadata: { comment: comment, net_amount: settlement.net_amount.to_f },
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
