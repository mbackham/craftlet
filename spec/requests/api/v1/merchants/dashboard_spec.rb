# frozen_string_literal: true

require 'rails_helper'

# spec/requests/api/v1/merchants/dashboard_spec.rb
#
# 商家看板数据 API 测试
# GET /api/v1/merchant/dashboard
#
RSpec.describe 'Merchant Dashboard API', type: :request do
  let(:logto_sub)   { 'logto-m-dash-001' }
  let(:logto_email) { 'm-dash@example.com' }
  let!(:merchant)   { create(:user, external_id: logto_sub, email: logto_email) }
  let!(:profile)    { create(:merchant_profile, user: merchant, status: 'approved') }
  let!(:customer)   { create(:user, email: 'cust-dash@example.com') }

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

  def create_merchant_order(attrs = {})
    create(:order, { merchant_id: merchant_uuid, customer_id: customer_uuid }.merge(attrs))
  end

  describe 'GET /api/v1/merchant/dashboard' do
    context 'without authentication' do
      it 'returns 401' do
        get '/api/v1/merchant/dashboard'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when merchant_profile is not approved' do
      before { profile.update!(status: 'submitted') }

      it 'returns 403' do
        get '/api/v1/merchant/dashboard', headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with approved merchant and some orders' do
      before do
        # 今日订单
        create_merchant_order(status: 'paid')
        create_merchant_order(status: 'producing')
        # 已完成（本月）
        create_merchant_order(status: 'completed', completed_at: Time.current)
        # 其他商家的订单（不应统计）
        create(:order, status: 'completed', completed_at: Time.current)
      end

      it 'returns 200 with dashboard stats' do
        get '/api/v1/merchant/dashboard', headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true

        data = body['data']
        expect(data).to include(
          'today_orders_count',
          'pending_accept_count',
          'producing_count',
          'delivering_count',
          'this_month_completed',
          'this_month_revenue',
          'total_completed_count',
          'merchant_status'
        )

        expect(data['merchant_status']).to eq('approved')
        expect(data['pending_accept_count']).to eq(1)   # paid 状态
        expect(data['producing_count']).to eq(1)
        expect(data['this_month_completed']).to eq(1)   # 只计本商家
        expect(data['total_completed_count']).to eq(1)
      end
    end
  end
end
