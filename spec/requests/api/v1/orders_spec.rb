# frozen_string_literal: true

require 'rails_helper'

# spec/requests/api/v1/orders_spec.rb
#
# 消费者端订单 API 测试
# GET  /api/v1/orders
# GET  /api/v1/orders/:id
# POST /api/v1/orders
# POST /api/v1/orders/:id/cancel
#
RSpec.describe 'Orders API (Consumer)', type: :request do
  let(:logto_sub)      { 'logto-order-user-001' }
  let(:logto_email)    { 'order@example.com' }
  let!(:customer)      { create(:user, external_id: logto_sub, email: logto_email) }
  let!(:merchant_user) { create(:user, email: 'merchant@example.com') }

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

  # 构造正确 UUID 编码的 customer_id 和 merchant_id
  def customer_uuid
    Order.id_to_uuid(customer.id)
  end

  def merchant_uuid
    Order.id_to_uuid(merchant_user.id)
  end

  # 创建属于当前用户的订单（AASM 初始状态为 created）
  def create_customer_order(attrs = {})
    create(:order, { customer_id: customer_uuid, merchant_id: merchant_uuid, status: 'created' }.merge(attrs))
  end

  # ── GET /api/v1/orders ───────────────────────────────────────────────────

  describe 'GET /api/v1/orders' do
    context 'without authentication' do
      it 'returns 401' do
        get '/api/v1/orders'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      let!(:my_orders)    { 2.times.map { create_customer_order } }
      let!(:other_orders) { create(:order) } # 其他用户的订单

      it 'returns only the current user\'s orders with pagination meta' do
        get '/api/v1/orders', headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body['data'].length).to eq(2)
        expect(body['meta']['total_count']).to eq(2)
        expect(body['meta']).to include('current_page', 'total_pages', 'per_page')
      end

      it 'returns orders sorted by created_at desc' do
        get '/api/v1/orders', headers: auth_headers
        body = JSON.parse(response.body)
        ids = body['data'].map { |o| o['id'] }
        expect(ids).to eq(my_orders.map(&:id).sort.reverse)
      end
    end
  end

  # ── GET /api/v1/orders/:id ───────────────────────────────────────────────

  describe 'GET /api/v1/orders/:id' do
    let!(:my_order)    { create_customer_order }
    let!(:other_order) { create(:order) }

    context 'without authentication' do
      it 'returns 401' do
        get "/api/v1/orders/#{my_order.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      it 'returns 200 with detail view for own order' do
        get "/api/v1/orders/#{my_order.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'id')).to eq(my_order.id)
        expect(body.dig('data', 'order_no')).to eq(my_order.order_no)
        expect(body['data']).to include('order_items', 'payments')
      end

      it 'returns 403 for another user\'s order' do
        get "/api/v1/orders/#{other_order.id}", headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end

      it 'returns 404 for non-existent order' do
        get '/api/v1/orders/999999', headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ── POST /api/v1/orders ──────────────────────────────────────────────────

  describe 'POST /api/v1/orders' do
    let(:valid_params) do
      {
        order: {
          merchant_id: merchant_uuid,
          total_amount: '299.00',
          currency: 'CNY'
        }
      }
    end

    context 'without authentication' do
      it 'returns 401' do
        post '/api/v1/orders', params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      it 'creates an order and returns 201' do
        expect {
          post '/api/v1/orders', params: valid_params, headers: auth_headers
        }.to change(Order, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'status')).to eq('created')
        expect(body.dig('data', 'total_amount')).to eq('299.0')

        # 验证 customer_id 正确设置为当前用户
        order = Order.last
        expect(order.customer_id).to eq(customer_uuid)
      end

      it 'generates a unique order_no' do
        post '/api/v1/orders', params: valid_params, headers: auth_headers
        order = Order.last
        expect(order.order_no).to match(/\AORD\d{14}[A-F0-9]{6}\z/)
      end
    end
  end

  # ── POST /api/v1/orders/:id/cancel ───────────────────────────────────────

  describe 'POST /api/v1/orders/:id/cancel' do
    let!(:cancellable_order) { create_customer_order(status: 'created') }
    let!(:paid_order)        { create_customer_order(status: 'paid') }
    let!(:completed_order)   { create_customer_order(status: 'completed') }
    let!(:other_order)       { create(:order, status: 'created') }

    context 'without authentication' do
      it 'returns 401' do
        post "/api/v1/orders/#{cancellable_order.id}/cancel"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      it 'cancels a cancellable order (created status)' do
        post "/api/v1/orders/#{cancellable_order.id}/cancel", headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'status')).to eq('canceled')
        expect(cancellable_order.reload.status).to eq('canceled')
      end

      it 'returns 422 when order cannot be cancelled (completed)' do
        post "/api/v1/orders/#{completed_order.id}/cancel", headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body['success']).to be false
        expect(body.dig('error', 'code')).to eq('invalid_state')
      end

      it 'returns 403 for another user\'s order' do
        post "/api/v1/orders/#{other_order.id}/cancel", headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end

      it 'returns 404 for non-existent order' do
        post '/api/v1/orders/999999/cancel', headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
