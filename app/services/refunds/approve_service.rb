# frozen_string_literal: true

module Refunds
  class ApproveService
    attr_reader :refund, :admin_user, :result

    def initialize(refund:, admin_user:, request: nil)
      @refund     = refund
      @admin_user = admin_user
      @request    = request
      @result     = { success: false, error: nil }
    end

    def call
      ActiveRecord::Base.transaction do
        # 悲观锁：防止并发重复审批
        @refund = refund.lock!

        validate!

        old_status = refund.status
        refund.update!(status: "pending")

        AuditService.log!(
          action:   "approve",
          actor:    admin_user,
          target:   refund,
          before:   { status: old_status },
          after:    { status: "pending" },
          metadata: { action_type: "refund_approval" },
          request:  @request
        )

        # 异步处理退款（传递 request_id 进行追踪）
        Refunds::ProcessRefundJob.perform_later(refund.id, request_id: @request&.request_id)
      end

      @result[:success] = true
      self
    rescue ActiveRecord::RecordInvalid => e
      @result[:error] = e.message
      self
    rescue => e
      @result[:error] = e.message
      self
    end

    def success?
      @result[:success]
    end

    def error
      @result[:error]
    end

    private

    def validate!
      unless refund.status == "init"
        raise ActiveRecord::RecordInvalid.new(refund),
              I18n.t("admin.errors.refund_approve_invalid_status", status: refund.status)
      end
    end
  end
end
