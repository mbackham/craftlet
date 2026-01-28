# frozen_string_literal: true

module Refunds
  class ApproveService
    attr_reader :refund, :admin_user, :result

    def initialize(refund:, admin_user:, request: nil)
      @refund = refund
      @admin_user = admin_user
      @request = request
      @result = { success: false, error: nil }
    end

    def call
      validate!
      
      ActiveRecord::Base.transaction do
        old_status = refund.status

        refund.update!(status: 'pending')

        AuditService.log!(
          action: 'approve',
          actor: admin_user,
          target: refund,
          before: { status: old_status },
          after: { status: 'pending' },
          metadata: { action_type: 'refund_approval' },
          request: @request
        )

        # Enqueue async job for refund processing
        Refunds::ProcessRefundJob.perform_later(refund.id)
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
      raise ActiveRecord::RecordInvalid.new(refund), '退款状态不允许审批' unless refund.status == 'init'
    end
  end
end
