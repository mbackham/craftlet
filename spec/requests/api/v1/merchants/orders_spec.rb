# frozen_string_literal: true

require 'rails_helper'

# spec/requests/api/v1/merchants/orders_spec.rb
#
# 商家端订单管理 API 测试
# GET  /api/v1/merchant/orders
# GET  /api/v1/merchant/orders/:id
# POST /api/v1/merchant/orders/:id/accept
# POST /api/v1/merchant/orders/:id/start_producing
# POST /api/v1/merchant/orders/:id/deliver
#
RSpec.describe 'Merchant Orders API', type: :request do
  let(:logto_sub)   { 'logto-m-order-001' }
  let(:logto_email) { 'm-order@example.com' }
  let!(:merchant)   { create(:user, external_id: logto_sub, email: logto_email) }
  let!(:profile)    { create(:merchant_profile, user: merchant, status: 'approved') }
  let!(:customer)   { create(:user, email: 'cust-morder@example.com') }

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

  def merchant_uuid; Order.id_to_uuid(merchant.id); end
  def customer_uuid; Order.id_to_uuid(customer.id); end

  # 创建属于当前商家的订单
  def create_merchant_order(attrs = {})
    create(:order, { merchant_id: merchant_uuid, customer_id: customer_uuid }.merge(attrs))
  end

  # ── GET /api/v1/merchant/orders ─────────────────────────────────────────

  describe 'GET /api/v1/merchant/orders' do
    context 'without authentication' do
      it 'returns 401' do
        get '/api/v1/merchant/orders'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when merchant_profile is not approved' do
      let!(:pending_profile) { profile.update!(status: 'submitted') }

      it 'returns 403' do
        get '/api/v1/merchant/orders', headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with approved merchant' do
      let!(:my_orders)    { 3.times.map { create_merchant_order } }
      let!(:other_orders) { create(:order) }

      it 'returns only the current merchant orders with pagination' do
        get '/api/v1/merchant/orders', headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body['data'].length).to eq(3)
        expect(body['meta']['total_count']).to eq(3)
      end

      it 'supports status filter' do
        create_merchant_order(status: 'paid')
        get '/api/v1/merchant/orders', params: { status: 'paid' }, headers: auth_headers

        body = JSON.parse(response.body)
        expect(body['data'].all? { |o| o['status'] == 'paid' }).to be true
      end

      it 'returns sorted by created_at desc' do
        get '/api/v1/merchant/orders', headers: auth_headers
        body = JSON.parse(response.body)
        ids = body['data'].map { |o| o['id'] }
        expect(ids).to eq(my_orders.map(&:id).sort.reverse)
      end

      it 'includes pagination meta' do
        get '/api/v1/merchant/orders', headers: auth_headers
        body = JSON.parse(response.body)
        expect(body['meta']).to include('current_page', 'total_pages', 'total_count', 'per_page')
      end
    end
  end

  # ── GET /api/v1/merchant/orders/:id ─────────────────────────────────────

  describe 'GET /api/v1/merchant/orders/:id' do
    let!(:my_order)    { create_merchant_order(status: 'paid') }
    let!(:other_order) { create(:order) }

    context 'without authentication' do
      it 'returns 401' do
        get "/api/v1/merchant/orders/#{my_order.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      it 'returns 200 with merchant_detail view for own order' do
        get "/api/v1/merchant/orders/#{my_order.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'id')).to eq(my_order.id)
        expect(body.dig('data', 'status')).to eq('paid')
        expect(body['data']).to include('order_items')
      end

      it 'returns 404 for another merchant\'s order' do
        get "/api/v1/merchant/orders/#{other_order.id}", headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ── POST /api/v1/merchant/orders/:id/accept ─────────────────────────────

  describe 'POST /api/v1/merchant/orders/:id/accept' do
    let!(:paid_order)      { create_merchant_order(status: 'paid') }
    let!(:created_order)   { create_merchant_order(status: 'created') }
    let!(:other_order)     { create(:order, status: 'paid') }

    context 'without authentication' do
      it 'returns 401' do
        post "/api/v1/merchant/orders/#{paid_order.id}/accept"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      it 'transitions order from paid to accepted' do
        post "/api/v1/merchant/orders/#{paid_order.id}/accept", headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'status')).to eq('accepted')
        expect(paid_order.reload.status).to eq('accepted')
      end

      it 'returns 422 when order is not in paid status (created)' do
        post "/api/v1/merchant/orders/#{created_order.id}/accept", headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body.dig('error', 'code')).to eq('invalid_state')
      end

      it 'returns 404 for another merchant\'s order' do
        post "/api/v1/merchant/orders/#{other_order.id}/accept", headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ── POST /api/v1/merchant/orders/:id/start_producing ────────────────────

  describe 'POST /api/v1/merchant/orders/:id/start_producing' do
    let!(:accepted_order) { create_merchant_order(status: 'accepted') }
    let!(:paid_order)     { create_merchant_order(status: 'paid') }

    context 'without authentication' do
      it 'returns 401' do
        post "/api/v1/merchant/orders/#{accepted_order.id}/start_producing"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      it 'transitions order from accepted to producing' do
        post "/api/v1/merchant/orders/#{accepted_order.id}/start_producing", headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body.dig('data', 'status')).to eq('producing')
        expect(accepted_order.reload.status).to eq('producing')
      end

      it 'returns 422 when order is not in accepted status' do
        post "/api/v1/merchant/orders/#{paid_order.id}/start_producing", headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body.dig('error', 'code')).to eq('invalid_state')
      end
    end
  end

  # ── POST /api/v1/merchant/orders/:id/deliver ────────────────────────────

  describe 'POST /api/v1/merchant/orders/:id/deliver' do
    let!(:producing_order) { create_merchant_order(status: 'producing') }
    let!(:accepted_order)  { create_merchant_order(status: 'accepted') }

    context 'without authentication' do
      it 'returns 401' do
        post "/api/v1/merchant/orders/#{producing_order.id}/deliver"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      it 'transitions order from producing to delivered' do
        post "/api/v1/merchant/orders/#{producing_order.id}/deliver", headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body.dig('data', 'status')).to eq('delivered')
        expect(producing_order.reload.status).to eq('delivered')
      end

      it 'returns 422 when order is not in producing status' do
        post "/api/v1/merchant/orders/#{accepted_order.id}/deliver", headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body.dig('error', 'code')).to eq('invalid_state')
      end
    end
  end

  # ── 完整工作流：paid → accepted → producing → delivered ────────────────

  describe 'Full merchant order workflow' do
    it 'transitions through full lifecycle' do
      order = create_merchant_order(status: 'paid')

      post "/api/v1/merchant/orders/#{order.id}/accept", headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(order.reload.status).to eq('accepted')

      post "/api/v1/merchant/orders/#{order.id}/start_producing", headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(order.reload.status).to eq('producing')

      post "/api/v1/merchant/orders/#{order.id}/deliver", headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(order.reload.status).to eq('delivered')
    end
  end
end
