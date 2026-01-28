# frozen_string_literal: true

module Refunds
  class RejectService
    attr_reader :refund, :admin_user, :reason, :result

    def initialize(refund:, admin_user:, reason: nil, request: nil)
      @refund = refund
      @admin_user = admin_user
      @reason = reason || '审核拒绝'
      @request = request
      @result = { success: false, error: nil }
    end

    def call
      validate!
      
      ActiveRecord::Base.transaction do
        old_status = refund.status

        refund.update!(status: 'failed')

        AuditService.log!(
          action: 'reject',
          actor: admin_user,
          target: refund,
          before: { status: old_status },
          after: { status: 'failed' },
          metadata: { action_type: 'refund_rejection', reason: reason },
          request: @request
        )
      end

      @result[:success] = true
      self
    rescue ActiveRecord::RecordInvalid => e
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
      raise ActiveRecord::RecordInvalid.new(refund), '退款状态不允许拒绝' unless refund.status == 'init'
    end
  end
end
