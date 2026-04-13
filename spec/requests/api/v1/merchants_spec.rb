# frozen_string_literal: true

require 'swagger_helper'
require 'openssl'

RSpec.describe 'Merchants API', type: :request do
  # Week 1: 认证改为 Logto JWT；stub JwtVerifier 避免真实 JWKS 调用
  # Week 1: auth changed to Logto JWT; stub JwtVerifier to avoid real JWKS calls

  let(:logto_sub) { 'logto-merchant-spec-001' }
  let!(:test_user) { create(:user, external_id: logto_sub, email: 'merchant-spec@example.com') }
  let(:valid_claims) do
    Auth::TokenClaims.new(sub: logto_sub, email: 'merchant-spec@example.com',
                          name: nil, phone_number: nil, raw: {})
  end

  path '/api/v1/merchant/status' do
    get '获取商家审核状态' do
      tags '商家'
      description '返回当前登录用户的商家入驻审核状态。需要 Logto JWT 认证。'
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: 'Bearer <Logto JWT>'

      response '200', '获取成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     status: {
                       type: :string,
                       enum: %w[not_applied pending submitted approved rejected suspended],
                       description: '审核状态'
                     },
                     shop_name:       { type: :string, nullable: true },
                     message:         { type: :string },
                     rejected_reason: { type: :string, nullable: true },
                     approved_at:     { type: :string, nullable: true, format: 'date-time' },
                     rejected_at:     { type: :string, nullable: true, format: 'date-time' },
                     created_at:      { type: :string, nullable: true, format: 'date-time' }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '401', '未登录或 Token 无效' do
        let(:Authorization) { 'Bearer invalid.token' }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end
        run_test!
      end
    end
  end
end
