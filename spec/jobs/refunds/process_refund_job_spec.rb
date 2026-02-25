# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Refunds::ProcessRefundJob, type: :job do
  # ---------------------------------------------------------------------------
  # Test helpers / factories
  # ---------------------------------------------------------------------------
  def create_order(status: "paid")
    Order.create!(
      order_no:     "ORD-TEST-#{SecureRandom.hex(4)}",
      customer_id:  SecureRandom.uuid,
      merchant_id:  SecureRandom.uuid,
      status:       status,
      total_amount: 100.00,
      currency:     "CNY"
    )
  end

  def create_payment(order:, channel: "wechat")
    Payment.create!(
      order:           order,
      channel:         channel,
      status:          "paid",
      amount:          100.00,
      currency:        "CNY",
      provider_trade_no: "WX_TRADE_#{SecureRandom.hex(6).upcase}",
      idempotency_key: "pay_#{SecureRandom.hex(8)}"
    )
  end

  def create_refund(payment:, order:, status: "pending")
    Refund.create!(
      order:           order,
      payment:         payment,
      amount:          100.00,
      reason:          "customer_request",
      status:          status,
      idempotency_key: "ref_#{SecureRandom.hex(8)}"
    )
  end

  # ---------------------------------------------------------------------------
  # 幂等性：非 pending 状态跳过执行
  # ---------------------------------------------------------------------------
  describe "idempotency guard" do
    it "skips execution when refund is already succeeded" do
      order   = create_order
      payment = create_payment(order: order)
      refund  = create_refund(order: order, payment: payment, status: "succeeded")

      expect {
        described_class.new.perform(refund.id)
      }.not_to change { refund.reload.status }
    end

    it "skips execution when refund is in failed status" do
      order   = create_order
      payment = create_payment(order: order)
      refund  = create_refund(order: order, payment: payment, status: "failed")

      expect {
        described_class.new.perform(refund.id)
      }.not_to change { refund.reload.status }
    end

    it "does nothing when refund record does not exist" do
      expect {
        described_class.new.perform(999_999_999)
      }.not_to raise_error
    end
  end

  # ---------------------------------------------------------------------------
  # Mock 模式：成功路径
  # ---------------------------------------------------------------------------
  describe "mock mode — success path (WECHAT_MCH_ID blank)" do
    before { allow(ENV).to receive(:[]).and_call_original }

    context "WeChat channel" do
      let(:order)   { create_order(status: "paid") }
      let(:payment) { create_payment(order: order, channel: "wechat") }
      let(:refund)  { create_refund(order: order, payment: payment, status: "pending") }

      it "transitions refund status to succeeded" do
        described_class.new.perform(refund.id)
        expect(refund.reload.status).to eq("succeeded")
      end

      it "sets succeeded_at timestamp" do
        described_class.new.perform(refund.id)
        expect(refund.reload.succeeded_at).not_to be_nil
      end

      it "stores provider_refund_no" do
        described_class.new.perform(refund.id)
        expect(refund.reload.provider_refund_no).to match(/\AWXR_MOCK_/i)
      end

      it "transitions order status to refunded" do
        described_class.new.perform(refund.id)
        expect(order.reload.status).to eq("refunded")
      end

      it "creates an AuditLog entry" do
        expect {
          described_class.new.perform(refund.id)
        }.to change(AuditLog, :count).by(1)

        log = AuditLog.last
        expect(log.action).to eq("process_refund_succeeded")
        expect(log.target_type).to eq("Refund")
        expect(log.target_id).to eq(refund.id)
      end
    end

    context "Alipay channel" do
      let(:order)   { create_order(status: "paid") }
      let(:payment) { create_payment(order: order, channel: "alipay") }
      let(:refund)  { create_refund(order: order, payment: payment, status: "pending") }

      it "transitions refund status to succeeded" do
        described_class.new.perform(refund.id)
        expect(refund.reload.status).to eq("succeeded")
      end

      it "stores provider_refund_no from Alipay" do
        described_class.new.perform(refund.id)
        expect(refund.reload.provider_refund_no).to match(/\AALIR_MOCK_/i)
      end

      it "transitions order status to refunded" do
        described_class.new.perform(refund.id)
        expect(order.reload.status).to eq("refunded")
      end
    end

    context "order already refunded (AASM idempotency)" do
      let(:order)   { create_order(status: "refunded") }
      let(:payment) { create_payment(order: order, channel: "wechat") }
      let(:refund)  { create_refund(order: order, payment: payment, status: "pending") }

      it "does not raise AASM error when order already refunded" do
        expect {
          described_class.new.perform(refund.id)
        }.not_to raise_error

        expect(refund.reload.status).to eq("succeeded")
        expect(order.reload.status).to  eq("refunded") # stays refunded
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 错误分类：Non-Retryable 错误 → status = failed
  # ---------------------------------------------------------------------------
  describe "error classification" do
    let(:order)   { create_order(status: "paid") }
    let(:payment) { create_payment(order: order, channel: "wechat") }
    let(:refund)  { create_refund(order: order, payment: payment, status: "pending") }

    before do
      allow_any_instance_of(Payments::WechatProvider)
        .to receive(:create_refund)
        .and_return({ success: false, error: error_msg, raw: {} })
    end

    context "with a non-retryable error (REFUND_FAILED)" do
      let(:error_msg) { "REFUND_FAILED: refund amount exceeds original payment" }

      it "marks refund as failed" do
        described_class.new.perform(refund.id)
        expect(refund.reload.status).to eq("failed")
      end

      it "writes an AuditLog with non_retryable: true" do
        described_class.new.perform(refund.id)
        log = AuditLog.where(action: "process_refund_failed").last
        expect(log).not_to be_nil
        expect(log.metadata["non_retryable"]).to eq(true)
      end
    end

    context "with a retryable error (transient network)" do
      let(:error_msg) { "Net::ReadTimeout: execution expired" }

      it "raises the error so Sidekiq can retry" do
        expect {
          described_class.new.perform(refund.id)
        }.to raise_error(RuntimeError, error_msg)
      end

      it "does NOT mark refund as failed" do
        begin
          described_class.new.perform(refund.id)
        rescue RuntimeError
          nil
        end
        expect(refund.reload.status).to eq("pending")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # ⚠️  留白测试（待执照后实现）
  # ⚠️  STUB TESTS — Pending Business License
  # ---------------------------------------------------------------------------
  describe "STUB: real provider integration (pending business license)" do
    it "is NOT implemented for WeChat Pay real HTTP calls" do
      # When WECHAT_MCH_ID is set, WechatProvider#create_refund returns an error
      # indicating the real integration is pending.
      # This test documents the expected behavior post-stub.
      provider = Payments::WechatProvider.new
      allow(provider).to receive(:mock_mode?).and_return(false)

      order   = create_order
      payment = create_payment(order: order, channel: "wechat")
      refund  = create_refund(order: order, payment: payment, status: "pending")

      response = provider.create_refund(refund: refund)
      expect(response[:success]).to eq(false)
      expect(response[:error]).to include("pending business license")
    end

    it "is NOT implemented for Alipay real HTTP calls" do
      provider = Payments::AlipayProvider.new
      allow(provider).to receive(:mock_mode?).and_return(false)

      order   = create_order
      payment = create_payment(order: order, channel: "alipay")
      refund  = create_refund(order: order, payment: payment, status: "pending")

      response = provider.create_refund(refund: refund)
      expect(response[:success]).to eq(false)
      expect(response[:error]).to include("pending business license")
    end
  end
end
