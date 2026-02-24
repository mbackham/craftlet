# frozen_string_literal: true

module Refunds
  class RejectService
    attr_reader :refund, :admin_user, :reason, :result

    def initialize(refund:, admin_user:, reason: nil, request: nil)
      @refund     = refund
      @admin_user = admin_user
      @reason     = reason.presence || I18n.t("admin.defaults.reject_reason")
      @request    = request
      @result     = { success: false, error: nil }
    end

    def call
      ActiveRecord::Base.transaction do
        # 悲观锁：防止并发重复拒绝
        @refund = refund.lock!

        validate!

        old_status = refund.status
        refund.update!(status: "failed")

        AuditService.log!(
          action:   "reject",
          actor:    admin_user,
          target:   refund,
          before:   { status: old_status },
          after:    { status: "failed" },
          metadata: { action_type: "refund_rejection", reason: reason },
          request:  @request
        )
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
              I18n.t("admin.errors.refund_reject_invalid_status", status: refund.status)
      end
    end
  end
end
