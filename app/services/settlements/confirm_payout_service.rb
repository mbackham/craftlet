# frozen_string_literal: true

module Settlements
  class ConfirmPayoutService
    attr_reader :settlement, :admin_user, :payout_reference, :comment, :request, :error

    def initialize(settlement:, admin_user:, payout_reference:, comment: nil, request: nil)
      @settlement = settlement
      @admin_user = admin_user
      @payout_reference = payout_reference
      @comment = comment
      @request = request
    end

    def call
      unless settlement.may_payout?
        @error = "当前状态(#{settlement.status})不允许打款"
        return self
      end

      if payout_reference.blank?
        @error = "打款凭证号不能为空"
        return self
      end

      ActiveRecord::Base.transaction do
        settlement.paid_out_by = admin_user.id
        settlement.paid_out_at = Time.current
        settlement.payout_reference = payout_reference
        settlement.payout!

        AuditService.log!(
          action: "payout_settlement",
          actor: admin_user,
          target: settlement,
          metadata: {
            comment: comment,
            payout_reference: payout_reference,
            net_amount: settlement.net_amount.to_f
          },
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
