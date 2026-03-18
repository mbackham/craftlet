# frozen_string_literal: true

module FundMonitoring
  class LargeAmountDetector
    # Default threshold: 50,000 CNY. Override via ENV['FUND_ALERT_THRESHOLD'].
    DEFAULT_THRESHOLD = BigDecimal(ENV.fetch("FUND_ALERT_THRESHOLD", "50000"))

    # Call with a Payment or Refund record.
    # Returns the created FundAlert, or nil if no alert is needed.
    def self.call(record)
      new(record).call
    end

    def initialize(record)
      @record    = record
      @threshold = DEFAULT_THRESHOLD
    end

    def call
      return nil unless alertable?
      return nil if duplicate_pending?

      FundAlert.create!(
        alert_type:   alert_type_for(@record),
        subject:      @record,
        amount:       @record.amount,
        threshold:    @threshold,
        status:       "pending"
      )
    end

    private

    def alertable?
      @record.amount >= @threshold
    end

    def duplicate_pending?
      FundAlert.where(
        subject_type: @record.class.name,
        subject_id:   @record.id,
        status:       "pending"
      ).exists?
    end

    def alert_type_for(record)
      case record
      when Payment    then "payment"
      when Refund     then "refund"
      when Settlement then "settlement"
      else "payment"
      end
    end
  end
end
