# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Payment Callbacks API", type: :request do
  # ---------------------------------------------------------------------------
  # Test helpers
  # ---------------------------------------------------------------------------
  def create_order(status: "paid")
    Order.create!(
      order_no:     "ORD-CB-#{SecureRandom.hex(4)}",
      customer_id:  SecureRandom.uuid,
      merchant_id:  SecureRandom.uuid,
      status:       status,
      total_amount: 100.00,
      currency:     "CNY"
    )
  end

  def create_payment(order:, channel: "wechat")
    Payment.create!(
      order:             order,
      channel:           channel,
      status:            "paid",
      amount:            100.00,
      currency:          "CNY",
      provider_trade_no: "WX_TRADE_#{SecureRandom.hex(6).upcase}",
      idempotency_key:   "pay_#{SecureRandom.hex(8)}"
    )
  end

  def create_refund(payment:, order:, status: "pending", provider_refund_no: nil)
    Refund.create!(
      order:              order,
      payment:            payment,
      amount:             100.00,
      reason:             "customer_request",
      status:             status,
      idempotency_key:    "ref_#{SecureRandom.hex(8)}",
      provider_refund_no: provider_refund_no
    )
  end

  let(:order)   { create_order(status: "paid") }

  # ---------------------------------------------------------------------------
  # WeChat Callback — POST /api/payments/callbacks/wechat
  # ---------------------------------------------------------------------------
  describe "POST /api/payments/callbacks/wechat" do
    let(:payment) { create_payment(order: order, channel: "wechat") }
    let(:refund_no) { "WXR_MOCK_#{SecureRandom.hex(8).upcase}" }
    let(:refund) do
      create_refund(order: order, payment: payment,
                    status: "pending", provider_refund_no: refund_no)
    end

    let(:wechat_payload) do
      {
        refund_id:    refund_no,
        out_refund_no: refund.idempotency_key,
        refund_fee:   10000
      }
    end

    context "valid callback with matching provider_refund_no" do
      before { refund } # ensure refund exists

      it "returns HTTP 200 with WeChat-format success body" do
        post "/api/payments/callbacks/wechat",
             params: wechat_payload.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["code"]).to eq("SUCCESS")
      end

      it "transitions refund status to succeeded" do
        post "/api/payments/callbacks/wechat",
             params: wechat_payload.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(refund.reload.status).to eq("succeeded")
      end

      it "transitions order status to refunded" do
        post "/api/payments/callbacks/wechat",
             params: wechat_payload.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(order.reload.status).to eq("refunded")
      end

      it "creates an AuditLog entry for the callback" do
        expect {
          post "/api/payments/callbacks/wechat",
               params: wechat_payload.to_json,
               headers: { "Content-Type" => "application/json" }
        }.to change(AuditLog, :count).by(1)

        log = AuditLog.last
        expect(log.action).to eq("callback_refund_succeeded")
        expect(log.metadata["channel"]).to eq("wechat")
      end
    end

    context "replay — duplicate callback for already-succeeded refund" do
      let!(:succeeded_refund) do
        create_refund(order: order, payment: payment,
                      status: "succeeded", provider_refund_no: refund_no)
      end

      let(:replay_payload) do
        { refund_id: refund_no, out_refund_no: succeeded_refund.idempotency_key, refund_fee: 10000 }
      end

      it "returns HTTP 200 (idempotent — WeChat requirement)" do
        post "/api/payments/callbacks/wechat",
             params: replay_payload.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["code"]).to eq("SUCCESS")
      end

      it "does NOT create a duplicate AuditLog" do
        expect {
          post "/api/payments/callbacks/wechat",
               params: replay_payload.to_json,
               headers: { "Content-Type" => "application/json" }
        }.not_to change(AuditLog, :count)
      end
    end

    context "unknown provider_refund_no" do
      it "returns HTTP 422" do
        post "/api/payments/callbacks/wechat",
             params: { refund_id: "WXR_UNKNOWN_XXX" }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "missing refund_id field" do
      it "returns HTTP 400" do
        post "/api/payments/callbacks/wechat",
             params: { other_field: "value" }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:bad_request)
      end
    end

    # ⚠️  STUB: Real WeChat signature verification (pending business license)
    context "STUB: signature verification (pending business license)" do
      it "bypasses signature in mock mode — verify_callback always returns true" do
        # In mock mode (WECHAT_MCH_ID blank), WechatProvider#verify_callback
        # always returns true. This test documents that the bypass is intentional.
        provider = Payments::WechatProvider.new
        result   = provider.verify_callback(headers: {}, payload: {})
        expect(result).to eq(true)
      end

      it "would return false in real mode without valid signature" do
        # When not in mock mode, verify_callback returns false (stub behavior)
        # until RSA-SHA256 verification is implemented.
        provider = Payments::WechatProvider.new
        allow(provider).to receive(:mock_mode?).and_return(false)
        expect(provider.verify_callback(headers: {}, payload: {})).to eq(false)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Alipay Callback — POST /api/payments/callbacks/alipay
  # ---------------------------------------------------------------------------
  describe "POST /api/payments/callbacks/alipay" do
    let(:payment) { create_payment(order: order, channel: "alipay") }
    let(:refund_no) { "ALIR_MOCK_#{SecureRandom.hex(8).upcase}" }
    let(:refund) do
      create_refund(order: order, payment: payment,
                    status: "pending", provider_refund_no: refund_no)
    end

    let(:alipay_payload) do
      {
        notify_type:    "refund_resultNotify",
        out_request_no: refund_no,
        trade_no:       payment.provider_trade_no,
        refund_fee:     "100.00"
      }
    end

    context "valid callback with matching out_request_no" do
      before { refund }

      it "returns HTTP 200 with Alipay-format 'success' body" do
        post "/api/payments/callbacks/alipay", params: alipay_payload
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq("success")
      end

      it "transitions refund status to succeeded" do
        post "/api/payments/callbacks/alipay", params: alipay_payload
        expect(refund.reload.status).to eq("succeeded")
      end

      it "transitions order status to refunded" do
        post "/api/payments/callbacks/alipay", params: alipay_payload
        expect(order.reload.status).to eq("refunded")
      end

      it "creates an AuditLog entry for the callback" do
        expect {
          post "/api/payments/callbacks/alipay", params: alipay_payload
        }.to change(AuditLog, :count).by(1)

        log = AuditLog.last
        expect(log.action).to eq("callback_refund_succeeded")
        expect(log.metadata["channel"]).to eq("alipay")
      end
    end

    context "replay — duplicate callback for already-succeeded refund" do
      let!(:succeeded_refund) do
        create_refund(order: order, payment: payment,
                      status: "succeeded", provider_refund_no: refund_no)
      end

      it "returns HTTP 200 'success' (idempotent — Alipay requirement)" do
        post "/api/payments/callbacks/alipay", params: alipay_payload
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq("success")
      end
    end

    context "unknown out_request_no" do
      it "returns 'fail' with HTTP 422" do
        post "/api/payments/callbacks/alipay",
             params: { out_request_no: "ALIR_UNKNOWN" }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to eq("fail")
      end
    end

    context "missing out_request_no" do
      it "returns 'fail' with HTTP 400" do
        post "/api/payments/callbacks/alipay", params: { other: "data" }
        expect(response).to have_http_status(:bad_request)
        expect(response.body).to eq("fail")
      end
    end

    # ⚠️  STUB: Real Alipay RSA2 signature verification (pending business license)
    context "STUB: signature verification (pending business license)" do
      it "bypasses signature in mock mode — verify_callback always returns true" do
        provider = Payments::AlipayProvider.new
        expect(provider.verify_callback(headers: {}, payload: {})).to eq(true)
      end

      it "would return false in real mode without valid RSA2 signature" do
        provider = Payments::AlipayProvider.new
        allow(provider).to receive(:mock_mode?).and_return(false)
        expect(provider.verify_callback(headers: {}, payload: {})).to eq(false)
      end
    end
  end
end
