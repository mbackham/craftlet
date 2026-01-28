# frozen_string_literal: true

module Merchants
  class ApproveService
    attr_reader :merchant_profile, :admin_user, :result

    def initialize(merchant_profile:, admin_user:, request: nil)
      @merchant_profile = merchant_profile
      @admin_user = admin_user
      @request = request
      @result = { success: false, error: nil }
    end

    def call
      validate!
      
      ActiveRecord::Base.transaction do
        old_status = merchant_profile.status
        admin_uuid = MerchantProfile.format_admin_id_as_uuid(admin_user.id)

        merchant_profile.update!(
          status: 'approved',
          approved_at: Time.current,
          approved_by_admin_id: admin_uuid
        )

        merchant_profile.review_logs.create!(
          action: 'approve',
          operator_admin_id: admin_uuid,
          note: '审核通过'
        )

        AuditService.log!(
          action: 'approve',
          actor: admin_user,
          target: merchant_profile,
          before: { status: old_status },
          after: { status: 'approved' },
          metadata: { action_type: 'merchant_approval' },
          request: @request
        )

        # Enqueue async job for post-approval tasks
        Merchants::PostApprovalJob.perform_later(merchant_profile.id)
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
      raise ActiveRecord::RecordInvalid.new(merchant_profile), '当前状态不允许审批通过' unless merchant_profile.can_approve?
    end
  end
end
