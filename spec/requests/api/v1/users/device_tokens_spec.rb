# frozen_string_literal: true

require 'rails_helper'

# spec/requests/api/v1/users/device_tokens_spec.rb
#
# 设备推送 Token API 测试
# POST   /api/v1/users/device_tokens
# DELETE /api/v1/users/device_tokens/:id
#
RSpec.describe 'Device Tokens API', type: :request do
  let(:logto_sub)   { 'logto-dt-user-001' }
  let(:logto_email) { 'dt@example.com' }
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

  # ── POST /api/v1/users/device_tokens ────────────────────────────────────

  describe 'POST /api/v1/users/device_tokens' do
    let(:valid_params) { { device_token: { token: 'ExpoToken[abc123]', platform: 'ios' } } }

    context 'without authentication' do
      it 'returns 401' do
        post '/api/v1/users/device_tokens', params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      it 'creates a device token and returns 201' do
        expect {
          post '/api/v1/users/device_tokens', params: valid_params, headers: auth_headers
        }.to change(DeviceToken, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'token')).to eq('ExpoToken[abc123]')
        expect(body.dig('data', 'platform')).to eq('ios')
      end

      it 'is idempotent: upserts existing token (same token, different call)' do
        DeviceToken.create!(user: user, token: 'ExpoToken[abc123]', platform: 'ios')

        expect {
          post '/api/v1/users/device_tokens', params: valid_params, headers: auth_headers
        }.not_to change(DeviceToken, :count)

        expect(response).to have_http_status(:created)
      end

      it 'returns 422 for invalid platform' do
        post '/api/v1/users/device_tokens',
             params: { device_token: { token: 'ExpoToken[abc]', platform: 'windows' } },
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body['success']).to be false
      end

      it 'returns 422 when token is missing' do
        post '/api/v1/users/device_tokens',
             params: { device_token: { platform: 'android' } },
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ── DELETE /api/v1/users/device_tokens/:id ──────────────────────────────

  describe 'DELETE /api/v1/users/device_tokens/:id' do
    let!(:device_token) { DeviceToken.create!(user: user, token: 'ExpoToken[del123]', platform: 'android') }

    context 'without authentication' do
      it 'returns 401' do
        delete "/api/v1/users/device_tokens/#{device_token.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      it 'deletes the token and returns 204' do
        expect {
          delete "/api/v1/users/device_tokens/#{device_token.id}", headers: auth_headers
        }.to change(DeviceToken, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end

      it 'returns 404 for non-existent token' do
        delete '/api/v1/users/device_tokens/999999', headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
