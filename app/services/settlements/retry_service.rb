# frozen_string_literal: true

module Settlements
  class RetryService
    attr_reader :settlement, :admin_user, :comment, :request, :error

    def initialize(settlement:, admin_user:, comment: nil, request: nil)
      @settlement = settlement
      @admin_user = admin_user
      @comment = comment
      @request = request
    end

    def call
      unless settlement.may_retry_settlement?
        @error = "当前状态(#{settlement.status})不允许重试"
        return self
      end

      ActiveRecord::Base.transaction do
        settlement.failure_reason = nil
        settlement.frozen_reason = nil
        settlement.retry_settlement!

        AuditService.log!(
          action: "retry_settlement",
          actor: admin_user,
          target: settlement,
          metadata: { comment: comment },
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
