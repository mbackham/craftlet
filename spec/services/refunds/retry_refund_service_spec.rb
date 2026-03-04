# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Refunds::RetryRefundService do
  before { ActiveJob::Base.queue_adapter = :test }

  def create_order(status: "paid")
    Order.create!(
      order_no:     "ORD-#{SecureRandom.hex(4).upcase}",
      customer_id:  SecureRandom.uuid,
      merchant_id:  SecureRandom.uuid,
      status:       status,
      total_amount: 100.00,
      currency:     "CNY"
    )
  end

  def create_payment(order:)
    Payment.create!(
      order:           order,
      channel:         "wechat",
      amount:          order.total_amount,
      currency:        "CNY",
      status:          "paid",
      paid_at:         Time.current,
      idempotency_key: SecureRandom.uuid
    )
  end

  def create_refund(order:, payment:, status: "failed")
    Refund.create!(
      order:             order,
      payment:           payment,
      amount:            50.00,
      reason:            "Test refund",
      status:            status,
      idempotency_key:   SecureRandom.uuid,
      provider_refund_no: "RF-#{SecureRandom.hex(6)}",
      response_payload:  { error: "NETWORK_TIMEOUT" }
    )
  end

  let(:order)      { create_order }
  let(:payment)    { create_payment(order: order) }
  let(:refund)     { create_refund(order: order, payment: payment) }
  let(:admin_user) { AdminUser.first || AdminUser.create!(email: "admin@test.com", password: "Str0ng!Pass#12", password_confirmation: "Str0ng!Pass#12") }

  def run_service(overrides = {})
    Refunds::RetryRefundService.new(
      refund:     overrides[:refund] || refund,
      admin_user: overrides[:admin_user] || admin_user,
      request:    nil
    ).call
  end

  # ---------------------------------------------------------------------------
  # Success path
  # ---------------------------------------------------------------------------
  context "成功重试" do
    it "resets refund status from failed to pending" do
      result = run_service
      expect(result).to be_success
      expect(refund.reload.status).to eq("pending")
    end

    it "clears old response_payload" do
      run_service
      expect(refund.reload.response_payload).to eq({})
    end

    it "enqueues ProcessRefundJob" do
      expect {
        run_service
      }.to have_enqueued_job(Refunds::ProcessRefundJob).with(refund.id)
    end

    it "creates an AuditLog entry" do
      expect { run_service }.to change(AuditLog, :count).by(1)
      log = AuditLog.last
      expect(log.action).to eq("refund_retry")
      expect(log.before).to eq({ "status" => "failed" })
      expect(log.after).to eq({ "status" => "pending" })
    end
  end

  # ---------------------------------------------------------------------------
  # Validation failures
  # ---------------------------------------------------------------------------
  context "状态不允许重试" do
    %w[init pending succeeded].each do |bad_status|
      it "rejects when refund status is #{bad_status}" do
        refund.update_column(:status, bad_status)
        result = run_service
        expect(result).not_to be_success
        expect(result.error).to include("不允许重试")
      end
    end
  end
end
