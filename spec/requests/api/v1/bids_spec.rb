# frozen_string_literal: true

require 'rails_helper'

# spec/requests/api/v1/bids_spec.rb
#
# 竞价 API 测试
# GET  /api/v1/orders/:order_id/bids → 查看订单报价列表
# POST /api/v1/orders/:order_id/bids → 提交报价
#
RSpec.describe 'Bids API', type: :request do
  let(:logto_sub)   { 'logto-bid-user-001' }
  let(:logto_email) { 'bidder@example.com' }
  let!(:bidder)     { create(:user, external_id: logto_sub, email: logto_email) }
  let!(:customer)   { create(:user, email: 'bid-customer@example.com') }

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

  # customer 是订单的创建者
  let!(:order) do
    create(:order,
           customer_id: Order.id_to_uuid(customer.id),
           merchant_id: Order.id_to_uuid(bidder.id),
           status: 'created')
  end

  # ── GET /api/v1/orders/:order_id/bids ───────────────────────────────────

  describe 'GET /api/v1/orders/:order_id/bids' do
    let!(:existing_bids) do
      2.times.map do |i|
        Bid.create!(
          order: order,
          bidder_id: Bid.id_to_uuid(bidder.id),
          amount: (100 + i * 50).to_d,
          status: 'pending'
        )
      end
    end

    context 'without authentication' do
      it 'returns 401' do
        get "/api/v1/orders/#{order.id}/bids"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when current user is NOT the customer' do
      it 'returns 403 (bidder cannot view all bids)' do
        # 当前登录用户是 bidder，不是 customer
        get "/api/v1/orders/#{order.id}/bids", headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when current user IS the customer' do
      let(:customer_claims) do
        Auth::TokenClaims.new(
          sub: customer.external_id || 'logto-customer', email: customer.email,
          name: nil, phone_number: nil, raw: {}
        )
      end

      before do
        # 确保 customer 有 external_id
        customer.update!(external_id: 'logto-bid-customer-001')
      end

      def customer_auth_headers
        allow(Auth::JwtVerifier).to receive(:call).and_return(
          Auth::TokenClaims.new(
            sub: 'logto-bid-customer-001', email: customer.email,
            name: nil, phone_number: nil, raw: {}
          )
        )
        { 'Authorization' => 'Bearer customer.valid.token' }
      end

      it 'returns 200 with all bids' do
        get "/api/v1/orders/#{order.id}/bids", headers: customer_auth_headers
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body['data'].length).to eq(2)
      end
    end
  end

  # ── POST /api/v1/orders/:order_id/bids ──────────────────────────────────

  describe 'POST /api/v1/orders/:order_id/bids' do
    let(:valid_params) { { amount: '250.00' } }

    context 'without authentication' do
      it 'returns 401' do
        post "/api/v1/orders/#{order.id}/bids", params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      it 'creates a bid and returns 201' do
        expect {
          post "/api/v1/orders/#{order.id}/bids",
               params: valid_params,
               headers: auth_headers
        }.to change(Bid, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'amount')).to eq('250.0')
        expect(body.dig('data', 'status')).to eq('pending')

        # 验证 bidder_id 正确设置为 UUID 编码格式
        bid = Bid.last
        expect(bid.bidder_id).to eq(Bid.id_to_uuid(bidder.id))
      end

      it 'returns 404 for non-existent order' do
        post '/api/v1/orders/999999/bids', params: valid_params, headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end

      it 'returns 422 for invalid amount (zero)' do
        post "/api/v1/orders/#{order.id}/bids",
             params: { amount: '0' },
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
