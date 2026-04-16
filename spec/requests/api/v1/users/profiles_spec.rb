# frozen_string_literal: true

require 'rails_helper'

# spec/requests/api/v1/users/profiles_spec.rb
#
# 用户资料 API 测试
# GET  /api/v1/users/profile
# PATCH /api/v1/users/profile
#
RSpec.describe 'User Profile API', type: :request do
  let(:logto_sub)   { 'logto-profile-user-001' }
  let(:logto_email) { 'profile@example.com' }
  let!(:user) do
    create(:user,
           external_id: logto_sub,
           email: logto_email,
           nickname: 'TestUser',
           locale: 'zh-CN',
           country_code: 'CN')
  end

  let(:valid_claims) do
    Auth::TokenClaims.new(
      sub: logto_sub, email: logto_email,
      name: 'Test User', phone_number: nil, raw: {}
    )
  end

  def auth_headers
    allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims)
    { 'Authorization' => 'Bearer valid.test.token' }
  end

  # ── GET /api/v1/users/profile ────────────────────────────────────────────

  describe 'GET /api/v1/users/profile' do
    context 'without authentication' do
      it 'returns 401' do
        get '/api/v1/users/profile'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      it 'returns 200 with user profile data' do
        get '/api/v1/users/profile', headers: auth_headers
        expect(response).to have_http_status(:ok)

        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'id')).to eq(user.id)
        expect(body.dig('data', 'email')).to eq(logto_email)
        # UserSyncService 会将 nickname 同步为 TokenClaims 中的 name
        # UserSyncService syncs nickname from the TokenClaims name field
        expect(body.dig('data', 'nickname')).to eq('Test User')
        expect(body.dig('data', 'locale')).to eq('zh-CN')
        expect(body.dig('data', 'status')).to eq('active')
      end
    end
  end

  # ── PATCH /api/v1/users/profile ──────────────────────────────────────────

  describe 'PATCH /api/v1/users/profile' do
    context 'without authentication' do
      it 'returns 401' do
        patch '/api/v1/users/profile', params: { user: { nickname: 'New' } }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT and valid params' do
      it 'updates locale and returns updated profile' do
        patch '/api/v1/users/profile',
              params: { user: { locale: 'en', nickname: 'Updated Name' } },
              headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'locale')).to eq('en')
        expect(body.dig('data', 'nickname')).to eq('Updated Name')

        # 验证数据库已更新
        expect(user.reload.locale).to eq('en')
        expect(user.reload.nickname).to eq('Updated Name')
      end

      it 'updates country_code' do
        patch '/api/v1/users/profile',
              params: { user: { country_code: 'INTL' } },
              headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(user.reload.country_code).to eq('INTL')
      end
    end

    context 'with invalid params (disallowed fields)' do
      it 'ignores disallowed fields (e.g., status) and succeeds' do
        patch '/api/v1/users/profile',
              params: { user: { status: 'disabled', locale: 'en' } },
              headers: auth_headers

        expect(response).to have_http_status(:ok)
        # status 不在 permit 列表中，应被忽略
        expect(user.reload.status).to eq('active')
      end
    end
  end
end
