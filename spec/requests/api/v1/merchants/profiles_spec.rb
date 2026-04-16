# frozen_string_literal: true

require 'rails_helper'

# spec/requests/api/v1/merchants/profiles_spec.rb
#
# 商家资料管理 API 测试
# GET   /api/v1/merchant/profile
# PATCH /api/v1/merchant/profile
#
RSpec.describe 'Merchant Profile Management API', type: :request do
  let(:logto_sub)   { 'logto-m-profile-001' }
  let(:logto_email) { 'm-profile@example.com' }
  let!(:merchant)   { create(:user, external_id: logto_sub, email: logto_email) }
  let!(:profile)    { create(:merchant_profile, user: merchant, status: 'approved', shop_name: '原始工坊') }

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

  # ── GET /api/v1/merchant/profile ─────────────────────────────────────────

  describe 'GET /api/v1/merchant/profile' do
    context 'without authentication' do
      it 'returns 401' do
        get '/api/v1/merchant/profile'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user has no merchant_profile' do
      let!(:no_profile_user) do
        create(:user, external_id: 'logto-no-profile', email: 'no-profile@example.com')
      end
      let(:no_profile_claims) do
        Auth::TokenClaims.new(sub: 'logto-no-profile', email: 'no-profile@example.com',
                              name: nil, phone_number: nil, raw: {})
      end

      it 'returns 404' do
        allow(Auth::JwtVerifier).to receive(:call).and_return(no_profile_claims)
        get '/api/v1/merchant/profile', headers: { 'Authorization' => 'Bearer token' }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with valid JWT and existing profile' do
      it 'returns 200 with detail view' do
        get '/api/v1/merchant/profile', headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'shop_name')).to eq('原始工坊')
        expect(body.dig('data', 'status')).to eq('approved')
        # detail view 应含地址信息
        expect(body['data']).to include('full_address')
      end
    end
  end

  # ── PATCH /api/v1/merchant/profile ───────────────────────────────────────

  describe 'PATCH /api/v1/merchant/profile' do
    context 'without authentication' do
      it 'returns 401' do
        patch '/api/v1/merchant/profile', params: { merchant: { shop_name: 'New' } }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT and valid params' do
      it 'updates shop_name and returns 200' do
        patch '/api/v1/merchant/profile',
              params: { merchant: { shop_name: '新工坊名称', bank_name: '工商银行' } },
              headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'shop_name')).to eq('新工坊名称')
        expect(profile.reload.shop_name).to eq('新工坊名称')
        expect(profile.reload.bank_name).to eq('工商银行')
      end
    end

    context 'with invalid params (shop_name blank)' do
      it 'returns 422' do
        patch '/api/v1/merchant/profile',
              params: { merchant: { shop_name: '' } },
              headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body['success']).to be false
      end
    end
  end
end
