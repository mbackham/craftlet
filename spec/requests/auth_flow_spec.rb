# frozen_string_literal: true

require 'rails_helper'
require 'openssl'

# spec/requests/auth_flow_spec.rb
#
# Logto JWT 认证流程端到端请求测试
# End-to-end request tests for the Logto JWT authentication flow
#
# 策略 / Strategy:
#   生成临时 RSA 密钥对，用 JWT gem 签发 token，stub Auth::JwtVerifier.call
#   让 ExternalJwtAuthenticatable concern 可以验证 token 而无需真实 Logto 服务。
#
#   Generates an ephemeral RSA key pair, signs tokens with the JWT gem, and stubs
#   Auth::JwtVerifier.call so ExternalJwtAuthenticatable can verify tokens without
#   a real Logto service.
#
RSpec.describe 'Logto JWT auth flow', type: :request do
  # -----------------------------------------------------------------------
  # 共享 JWT 帮助方法 / Shared JWT helpers
  # -----------------------------------------------------------------------
  let(:logto_sub) { 'logto-e2e-user-001' }
  let(:logto_email) { 'e2e@example.com' }

  # 返回 Auth::TokenClaims 对象（模拟验证通过）
  # Returns an Auth::TokenClaims object (simulates successful verification)
  let(:valid_claims) do
    Auth::TokenClaims.new(
      sub:          logto_sub,
      email:        logto_email,
      name:         'E2E User',
      phone_number: nil,
      raw:          {}
    )
  end

  # 让 JwtVerifier 返回合法 claims（跳过真实 JWKS 网络调用）
  # Make JwtVerifier return valid claims (bypass real JWKS network call)
  def with_valid_token(&block)
    allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims)
    block.call
  end

  # 让 JwtVerifier 抛出 VerificationError（模拟 token 无效）
  # Make JwtVerifier raise VerificationError (simulate invalid token)
  def with_invalid_token(&block)
    allow(Auth::JwtVerifier).to receive(:call)
      .and_raise(Auth::JwtVerifier::VerificationError, 'Token is invalid')
    block.call
  end

  # 合法 Bearer token header
  def auth_header(token = 'valid.test.token')
    { 'Authorization' => "Bearer #{token}" }
  end

  # -----------------------------------------------------------------------
  # 受保护端点：GET /api/v1/merchant/status
  # Protected endpoint: GET /api/v1/merchant/status
  # -----------------------------------------------------------------------
  describe 'GET /api/v1/merchant/status' do
    context 'with no Authorization header' do
      it 'returns 401 with missing_token code' do
        get '/api/v1/merchant/status'
        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body['success']).to be false
        expect(body.dig('error', 'code')).to eq('unauthorized')
      end
    end

    context 'with an invalid token' do
      it 'returns 401 with invalid_token code' do
        with_invalid_token do
          get '/api/v1/merchant/status', headers: auth_header('bad.token')
        end
        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body['success']).to be false
        expect(body.dig('error', 'code')).to eq('unauthorized')
      end
    end

    context 'with a valid token (no merchant profile)' do
      let!(:user) { create(:user, external_id: logto_sub, email: logto_email) }

      it 'returns 200 with not_applied status' do
        with_valid_token do
          get '/api/v1/merchant/status', headers: auth_header
        end
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'status')).to eq('not_applied')
      end
    end

    context 'with a valid token (existing merchant profile)' do
      let!(:user) { create(:user, external_id: logto_sub, email: logto_email) }
      let!(:profile) do
        MerchantProfile.create!(
          user:       user,
          shop_name:  'E2E Shop',
          status:     'approved',
          created_at: Time.current
        )
      end

      it 'returns the merchant profile data' do
        with_valid_token do
          get '/api/v1/merchant/status', headers: auth_header
        end
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'status')).to eq('approved')
        expect(body.dig('data', 'shop_name')).to eq('E2E Shop')
      end
    end
  end

  # -----------------------------------------------------------------------
  # 公开端点：GET /api/v1/banners
  # Public endpoint: GET /api/v1/banners
  # -----------------------------------------------------------------------
  describe 'GET /api/v1/banners' do
    it 'returns 200 without any Authorization header' do
      get '/api/v1/banners'
      expect(response).to have_http_status(:ok)
    end

    it 'returns 200 even with an invalid token (no auth required)' do
      # 公开端点不应因 token 无效而拒绝
      # Public endpoints must NOT reject due to invalid token
      get '/api/v1/banners', headers: auth_header('garbage')
      expect(response).to have_http_status(:ok)
    end
  end

  # -----------------------------------------------------------------------
  # 公开端点：GET /api/v1/announcements
  # Public endpoint: GET /api/v1/announcements
  # -----------------------------------------------------------------------
  describe 'GET /api/v1/announcements' do
    it 'returns 200 without Authorization header' do
      get '/api/v1/announcements'
      expect(response).to have_http_status(:ok)
    end
  end

  # -----------------------------------------------------------------------
  # 公开端点：GET /api/v1/faqs
  # Public endpoint: GET /api/v1/faqs
  # -----------------------------------------------------------------------
  describe 'GET /api/v1/faqs' do
    it 'returns 200 without Authorization header' do
      get '/api/v1/faqs'
      expect(response).to have_http_status(:ok)
    end
  end

  # -----------------------------------------------------------------------
  # 自动用户同步验证 / Auto user sync verification
  # -----------------------------------------------------------------------
  describe 'Auto user sync on first login' do
    it 'creates a User record if none exists for the logto_sub' do
      expect {
        with_valid_token do
          get '/api/v1/merchant/status', headers: auth_header
        end
      }.to change(User, :count).by(1)

      user = User.find_by(external_id: logto_sub)
      expect(user).not_to be_nil
      expect(user.email).to eq(logto_email)
      expect(user.auth_provider).to eq('logto')
    end

    it 'does NOT create a second User on subsequent requests' do
      create(:user, external_id: logto_sub, email: logto_email)

      expect {
        with_valid_token do
          get '/api/v1/merchant/status', headers: auth_header
        end
      }.not_to change(User, :count)
    end
  end

  # -----------------------------------------------------------------------
  # 语言切换 / Locale switching
  # -----------------------------------------------------------------------
  describe 'Locale switching' do
    let!(:user) { create(:user, external_id: logto_sub, email: logto_email) }

    it 'returns Chinese error message by default' do
      get '/api/v1/merchant/status'
      body = JSON.parse(response.body)
      # missing_token 优先于 unauthorized / missing_token takes priority over unauthorized
      expect(body.dig('error', 'message')).to eq('缺少认证 Token，请在请求头中携带 Authorization: Bearer <token>')
    end

    it 'returns English error message with locale=en' do
      get '/api/v1/merchant/status', params: { locale: 'en' }
      body = JSON.parse(response.body)
      expect(body.dig('error', 'message')).to eq('Authentication token is missing. Please include Authorization: Bearer <token> in your request header')
    end

    it 'returns merchant status in Chinese by default' do
      with_valid_token do
        get '/api/v1/merchant/status', headers: auth_header
      end
      body = JSON.parse(response.body)
      expect(body.dig('data', 'message')).to eq('您尚未申请入驻')
    end

    it 'returns merchant status in English with locale=en' do
      with_valid_token do
        get '/api/v1/merchant/status', headers: auth_header, params: { locale: 'en' }
      end
      body = JSON.parse(response.body)
      expect(body.dig('data', 'message')).to eq('You have not applied for merchant onboarding yet')
    end
  end

  # -----------------------------------------------------------------------
  # Logto Webhook 端点
  # Logto Webhook endpoint
  # -----------------------------------------------------------------------
  describe 'POST /api/webhooks/logto' do
    let(:secret) { 'test-webhook-secret-12345' }
    let(:payload) { { event: 'User.Deleted', hookId: 'hook-001', data: { id: logto_sub } }.to_json }
    let(:valid_sig) { OpenSSL::HMAC.hexdigest('SHA256', secret, payload) }

    before do
      stub_const('ENV', ENV.to_hash.merge('LOGTO_WEBHOOK_SECRET' => secret))
    end

    context 'with valid HMAC signature' do
      it 'returns 200 and received: true' do
        post '/api/webhooks/logto',
             params: payload,
             headers: {
               'Content-Type'          => 'application/json',
               'logto-signature-sha-256'   => valid_sig
             }
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'received')).to be true
      end

      context 'when handling User.Deleted for an existing user' do
        let!(:user) { create(:user, external_id: logto_sub) }

        it 'deactivates the local user' do
          post '/api/webhooks/logto',
               params: payload,
               headers: {
                 'Content-Type'        => 'application/json',
                 'logto-signature-sha-256' => valid_sig
               }
          expect(user.reload.external_id).to be_nil
          expect(user.reload.status).to eq('deactivated')
        end
      end
    end

    context 'with invalid HMAC signature' do
      it 'returns 401' do
        post '/api/webhooks/logto',
             params: payload,
             headers: {
               'Content-Type'        => 'application/json',
               'logto-signature-sha-256' => 'wrong-signature'
             }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with no signature header' do
      it 'returns 401' do
        post '/api/webhooks/logto',
             params: payload,
             headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
