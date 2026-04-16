# frozen_string_literal: true

require 'rails_helper'

# spec/requests/api/v1/payments_spec.rb
#
# 支付 API 测试
# POST /api/v1/payments          → 创建支付单
# GET  /api/v1/payments/:id/status → 查询支付状态
#
RSpec.describe 'Payments API', type: :request do
  let(:logto_sub)      { 'logto-pay-user-001' }
  let(:logto_email)    { 'pay@example.com' }
  let!(:customer)      { create(:user, external_id: logto_sub, email: logto_email) }
  let!(:merchant_user) { create(:user, email: 'pay-merchant@example.com') }

  let(:valid_claims) do
    Auth::TokenClaims.new(
      sub: logto_sub, email: logto_email,
      name: nil, phone_number: nil, raw: {}
    )
  end

  def auth_headers
    allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims)
    { 'Authorization' => 'Bearer valid.test.token' }
  end

  def customer_uuid
    Order.id_to_uuid(customer.id)
  end

  def merchant_uuid
    Order.id_to_uuid(merchant_user.id)
  end

  let!(:order) do
    create(:order,
           customer_id: customer_uuid,
           merchant_id: merchant_uuid,
           status: 'created',
           total_amount: '188.00')
  end

  # ── POST /api/v1/payments ─────────────────────────────────────────────────

  describe 'POST /api/v1/payments' do
    context 'without authentication' do
      it 'returns 401' do
        post '/api/v1/payments', params: { order_id: order.id, channel: 'wechat' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      context 'with a valid wechat channel' do
        let(:mock_provider_response) do
          {
            success: true,
            provider_trade_no: "WX#{SecureRandom.hex(8).upcase}",
            raw: { prepay_id: 'wx_prepay_123', timeStamp: '1234567890' }
          }
        end

        before do
          allow_any_instance_of(Payments::WechatProvider)
            .to receive(:create_payment).and_return(mock_provider_response)
        end

        it 'creates a payment and returns 201 with pay_params' do
          expect {
            post '/api/v1/payments',
                 params: { order_id: order.id, channel: 'wechat' },
                 headers: auth_headers
          }.to change(Payment, :count).by(1)

          expect(response).to have_http_status(:created)
          body = JSON.parse(response.body)
          expect(body['success']).to be true
          expect(body.dig('data', 'channel')).to eq('wechat')
          expect(body.dig('data', 'amount')).to eq('188.0')
          expect(body.dig('data', 'status')).to eq('pending')
          expect(body.dig('data', 'pay_params')).to be_present
        end
      end

      context 'with an unsupported channel' do
        it 'returns 422 with unsupported_channel error' do
          post '/api/v1/payments',
               params: { order_id: order.id, channel: 'bitcoin' },
               headers: auth_headers

          expect(response).to have_http_status(:unprocessable_entity)
          body = JSON.parse(response.body)
          expect(body['success']).to be false
          expect(body.dig('error', 'code')).to eq('unsupported_channel')
        end
      end

      context 'when order does not belong to current user' do
        let!(:other_order) do
          create(:order, status: 'created', total_amount: '50.00')
        end

        it 'returns 403' do
          post '/api/v1/payments',
               params: { order_id: other_order.id, channel: 'wechat' },
               headers: auth_headers

          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'when order is not in created status' do
        let!(:paid_order) do
          create(:order,
                 customer_id: customer_uuid,
                 merchant_id: merchant_uuid,
                 status: 'paid',
                 total_amount: '100.00')
        end

        it 'returns 422 with invalid_order_status error' do
          post '/api/v1/payments',
               params: { order_id: paid_order.id, channel: 'wechat' },
               headers: auth_headers

          expect(response).to have_http_status(:unprocessable_entity)
          body = JSON.parse(response.body)
          expect(body.dig('error', 'code')).to eq('invalid_order_status')
        end
      end
    end
  end

  # ── GET /api/v1/payments/:id/status ──────────────────────────────────────

  describe 'GET /api/v1/payments/:id/status' do
    let!(:payment) do
      create(:payment, order: order, channel: 'wechat', status: 'paid', paid_at: Time.current)
    end

    context 'without authentication' do
      it 'returns 401' do
        get "/api/v1/payments/#{payment.id}/status"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT (own order)' do
      it 'returns 200 with payment status' do
        get "/api/v1/payments/#{payment.id}/status", headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'status')).to eq('paid')
        expect(body.dig('data', 'channel')).to eq('wechat')
        expect(body.dig('data', 'paid_at')).to be_present
      end
    end

    context 'when payment belongs to another user\'s order' do
      let!(:other_payment) { create(:payment) }

      it 'returns 403' do
        get "/api/v1/payments/#{other_payment.id}/status", headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with non-existent payment' do
      it 'returns 404' do
        get '/api/v1/payments/999999/status', headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
