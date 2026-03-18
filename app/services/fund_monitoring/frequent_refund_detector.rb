# frozen_string_literal: true

module FundMonitoring
  # Detects frequent refunds on the same payment and raises a RiskEvent.
  # Relies on the existing RiskRule / RiskEvent infrastructure.
  class FrequentRefundDetector
    RULE_CODE = "frequent_refund"

    def self.call(refund)
      new(refund).call
    end

    def initialize(refund)
      @refund = refund
    end

    def call
      rule = RiskRule.enabled.find_by(code: RULE_CODE)
      return nil if rule.nil?

      max_count   = rule.params.fetch("max_count", 3).to_i
      window_days = rule.params.fetch("window_days", 7).to_i

      recent_refunds = Refund
        .where(payment_id: @refund.payment_id)
        .where(created_at: window_days.days.ago..)
        .where.not(status: "failed")

      return nil unless recent_refunds.count >= max_count

      # Avoid duplicate pending events for the same payment
      subject_uuid = AuditService.format_as_uuid(user_id_for(@refund))
      already_exists = RiskEvent.where(
        risk_rule_id:   rule.id,
        subject_id:     subject_uuid,
        trigger_source: RULE_CODE
      ).where("created_at >= ?", window_days.days.ago).exists?

      return nil if already_exists

      RiskEvent.create!(
        risk_rule_id:   rule.id,
        status:         "pending",
        subject_id:     subject_uuid,
        subject_type:   "User",
        trigger_source: RULE_CODE,
        context: {
          payment_id:    @refund.payment_id,
          refund_ids:    recent_refunds.pluck(:id),
          refund_count:  recent_refunds.count,
          window_days:   window_days
        }
      )
    end

    private

    def user_id_for(refund)
      refund.order&.customer_id.to_s.split("-").last.to_i
    rescue StandardError
      0
    end
  end
end
