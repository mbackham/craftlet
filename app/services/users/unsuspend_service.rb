# frozen_string_literal: true

module Users
  class UnsuspendService
    attr_reader :user, :admin_user, :result

    def initialize(user:, admin_user:, request: nil)
      @user = user
      @admin_user = admin_user
      @request = request
      @result = { success: false, error: nil }
    end

    def call
      validate!
      
      ActiveRecord::Base.transaction do
        old_status = user.status
        old_reason = user.disabled_reason

        user.update!(
          status: 'active',
          disabled_at: nil,
          disabled_reason: nil
        )

        AuditService.log!(
          action: 'unsuspend',
          actor: admin_user,
          target: user,
          before: { status: old_status, disabled_reason: old_reason },
          after: { status: 'active' },
          metadata: { action_type: 'user_unsuspension' },
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
      raise ActiveRecord::RecordInvalid.new(user), '用户未被冻结' unless user.status == 'disabled'
    end
  end
end
