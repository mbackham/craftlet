# frozen_string_literal: true

module Merchants
  class RejectService
    attr_reader :merchant_profile, :admin_user, :reason, :result

    def initialize(merchant_profile:, admin_user:, reason:, request: nil)
      @merchant_profile = merchant_profile
      @admin_user = admin_user
      @reason = reason
      @request = request
      @result = { success: false, error: nil }
    end

    def call
      validate!
      
      ActiveRecord::Base.transaction do
        old_status = merchant_profile.status
        admin_uuid = MerchantProfile.format_admin_id_as_uuid(admin_user.id)

        merchant_profile.update!(
          status: 'rejected',
          rejected_at: Time.current,
          rejected_by_admin_id: admin_uuid,
          reject_reason: reason
        )

        merchant_profile.review_logs.create!(
          action: 'reject',
          operator_admin_id: admin_uuid,
          note: reason
        )

        AuditService.log!(
          action: 'reject',
          actor: admin_user,
          target: merchant_profile,
          before: { status: old_status },
          after: { status: 'rejected', reject_reason: reason },
          metadata: { action_type: 'merchant_rejection', reason: reason },
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
      raise ActiveRecord::RecordInvalid.new(merchant_profile), '当前状态不允许拒绝' unless merchant_profile.can_reject?
      raise ActiveRecord::RecordInvalid.new(merchant_profile), '请填写拒绝原因' if reason.blank?
    end
  end
end
