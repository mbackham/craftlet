# frozen_string_literal: true

require 'rails_helper'

# spec/requests/api/v1/merchants/settlements_spec.rb
#
# 商家结算查询 API 测试
# GET /api/v1/merchant/settlements
# GET /api/v1/merchant/settlements/:id
#
RSpec.describe 'Merchant Settlements API', type: :request do
  let(:logto_sub)   { 'logto-m-settle-001' }
  let(:logto_email) { 'm-settle@example.com' }
  let!(:merchant)   { create(:user, external_id: logto_sub, email: logto_email) }
  let!(:profile)    { create(:merchant_profile, user: merchant, status: 'approved') }
  let!(:other_merchant) { create(:user, email: 'other-settle@example.com') }
  let!(:other_profile)  { create(:merchant_profile, user: other_merchant) }

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

  # 为当前商家创建结算单（每次用不同周期避免唯一索引冲突）
  def create_settlement(attrs = {})
    offset = rand(1..999)
    create(:settlement, {
      merchant_profile: profile,
      period_start: (offset * 30).days.ago.to_date,
      period_end:   (offset * 30 - 7).days.ago.to_date
    }.merge(attrs))
  end

  # ── GET /api/v1/merchant/settlements ─────────────────────────────────────

  describe 'GET /api/v1/merchant/settlements' do
    context 'without authentication' do
      it 'returns 401' do
        get '/api/v1/merchant/settlements'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      let!(:my_settlements)    { 2.times.map { create_settlement } }
      let!(:other_settlement)  { create(:settlement, merchant_profile: other_profile) }

      it 'returns only current merchant\'s settlements with pagination' do
        get '/api/v1/merchant/settlements', headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body['data'].length).to eq(2)
        expect(body['meta']['total_count']).to eq(2)
      end

      it 'does NOT return other merchant\'s settlements' do
        get '/api/v1/merchant/settlements', headers: auth_headers
        body = JSON.parse(response.body)
        ids = body['data'].map { |s| s['id'] }
        expect(ids).not_to include(other_settlement.id)
      end
    end

    context 'when user has no merchant_profile' do
      let!(:no_profile_user) { create(:user, external_id: 'logto-no-mp', email: 'no-mp@example.com') }
      let(:no_profile_claims) do
        Auth::TokenClaims.new(sub: 'logto-no-mp', email: 'no-mp@example.com',
                              name: nil, phone_number: nil, raw: {})
      end

      it 'returns 404' do
        allow(Auth::JwtVerifier).to receive(:call).and_return(no_profile_claims)
        get '/api/v1/merchant/settlements', headers: { 'Authorization' => 'Bearer token' }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ── GET /api/v1/merchant/settlements/:id ─────────────────────────────────

  describe 'GET /api/v1/merchant/settlements/:id' do
    let!(:my_settlement)    { create_settlement(status: 'confirmed') }
    let!(:other_settlement) { create(:settlement, merchant_profile: other_profile) }

    context 'without authentication' do
      it 'returns 401' do
        get "/api/v1/merchant/settlements/#{my_settlement.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      it 'returns 200 with settlement detail (own)' do
        get "/api/v1/merchant/settlements/#{my_settlement.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'id')).to eq(my_settlement.id)
        expect(body.dig('data', 'status')).to eq('confirmed')
        # detail view 含明细字段
        expect(body['data']).to include('deposit_deduction', 'penalty_amount', 'payout_reference')
      end

      it 'returns 404 for another merchant\'s settlement' do
        get "/api/v1/merchant/settlements/#{other_settlement.id}", headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end

      it 'returns 404 for non-existent settlement' do
        get '/api/v1/merchant/settlements/999999', headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
