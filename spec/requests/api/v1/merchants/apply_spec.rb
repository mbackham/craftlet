# frozen_string_literal: true

require 'rails_helper'

# spec/requests/api/v1/merchants/apply_spec.rb
#
# 商家入驻申请 API 测试
# POST /api/v1/merchant/apply
#
RSpec.describe 'Merchant Apply API', type: :request do
  let(:logto_sub)   { 'logto-merchant-apply-001' }
  let(:logto_email) { 'apply@example.com' }
  let!(:user)       { create(:user, external_id: logto_sub, email: logto_email) }

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

  let(:valid_params) do
    {
      merchant: {
        shop_name:        '测试工坊',
        license_file_key: 'licenses/test.jpg',
        idcard_front_key: 'idcards/front.jpg',
        idcard_back_key:  'idcards/back.jpg',
        bank_name:        '招商银行',
        bank_branch:      '深圳南山支行',
        address_province: '广东省',
        address_city:     '深圳市',
        address_district: '南山区',
        address_detail:   '科技园A栋101'
      }
    }
  end

  # ── POST /api/v1/merchant/apply ──────────────────────────────────────────

  describe 'POST /api/v1/merchant/apply' do
    context 'without authentication' do
      it 'returns 401' do
        post '/api/v1/merchant/apply', params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT and valid params' do
      it 'creates MerchantProfile with submitted status and returns 201' do
        expect {
          post '/api/v1/merchant/apply', params: valid_params, headers: auth_headers
        }.to change(MerchantProfile, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'status')).to eq('submitted')
        expect(body.dig('data', 'shop_name')).to eq('测试工坊')
      end

      it 'associates the profile with current_user' do
        post '/api/v1/merchant/apply', params: valid_params, headers: auth_headers
        expect(user.reload.merchant_profile).not_to be_nil
        expect(user.merchant_profile.shop_name).to eq('测试工坊')
      end
    end

    context 'when user already has a merchant_profile' do
      let!(:existing_profile) { create(:merchant_profile, user: user, status: 'submitted') }

      it 'returns 422 with already_applied error' do
        post '/api/v1/merchant/apply', params: valid_params, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body['success']).to be false
        expect(body.dig('error', 'code')).to eq('already_applied')
      end
    end

    context 'with missing required fields (shop_name blank)' do
      let(:invalid_params) { { merchant: { shop_name: '', license_file_key: 'key.jpg' } } }

      it 'returns 422 with validation_error' do
        post '/api/v1/merchant/apply', params: invalid_params, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body['success']).to be false
        expect(body.dig('error', 'code')).to eq('validation_error')
      end
    end
  end
end
