# frozen_string_literal: true

module Users
  class SuspendService
    attr_reader :user, :admin_user, :reason, :result

    def initialize(user:, admin_user:, reason: nil, request: nil)
      @user = user
      @admin_user = admin_user
      @reason = reason || '管理员冻结'
      @request = request
      @result = { success: false, error: nil }
    end

    def call
      validate!
      
      ActiveRecord::Base.transaction do
        old_status = user.status

        user.update!(
          status: 'disabled',
          disabled_at: Time.current,
          disabled_reason: reason
        )

        AuditService.log!(
          action: 'suspend',
          actor: admin_user,
          target: user,
          before: { status: old_status },
          after: { status: 'disabled', disabled_reason: reason },
          metadata: { action_type: 'user_suspension', reason: reason },
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
      raise ActiveRecord::RecordInvalid.new(user), '用户已被冻结' if user.status == 'disabled'
    end
  end
end
