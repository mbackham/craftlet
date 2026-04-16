# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Device Tokens API', type: :request do
  let(:logto_sub)   { 'logto-dt-swagger-001' }
  let(:logto_email) { 'dt-swagger@example.com' }
  let!(:user)       { create(:user, external_id: logto_sub, email: logto_email) }
  let(:valid_claims) do
    Auth::TokenClaims.new(
      sub: logto_sub, email: logto_email,
      name: nil, phone_number: nil, raw: {}
    )
  end

  path '/api/v1/users/device_tokens' do
    post '注册设备推送 Token' do
      tags '用户'
      description '注册 Expo 推送 Token，用于接收订单状态变更等推送通知。同一 token 重复注册幂等处理（upsert）。需要 Logto JWT 认证。'
      security [Bearer: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: 'Bearer <Logto JWT>'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          device_token: {
            type: :object,
            properties: {
              token:    { type: :string, description: 'Expo Push Token，格式：ExpoToken[xxx]' },
              platform: { type: :string, enum: %w[ios android], description: '设备平台' }
            },
            required: %w[token platform]
          }
        },
        required: %w[device_token]
      }

      response '201', '注册成功（含幂等重复注册）' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:         { type: :integer },
                     token:      { type: :string },
                     platform:   { type: :string, enum: %w[ios android] },
                     created_at: { type: :string, format: 'date-time' }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:body) { { device_token: { token: 'ExpoToken[swagger123]', platform: 'ios' } } }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '401', '未登录或 Token 无效' do
        let(:Authorization) { 'Bearer invalid.token' }
        let(:body) { { device_token: { token: 'ExpoToken[abc]', platform: 'ios' } } }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end

        run_test!
      end

      response '422', '参数无效（platform 不合法或 token 缺失）' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 error: {
                   type: :object,
                   properties: {
                     code:    { type: :string },
                     message: { type: :string }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:body) { { device_token: { token: 'ExpoToken[abc]', platform: 'windows' } } }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end
  end

  path '/api/v1/users/device_tokens/{id}' do
    delete '注销设备推送 Token' do
      tags '用户'
      description '删除指定的设备推送 Token，用于退出登录或更换设备时清理推送订阅。需要 Logto JWT 认证。'
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: 'Bearer <Logto JWT>'

      parameter name: :id, in: :path, type: :integer, required: true, description: '设备 Token ID'

      response '204', '删除成功' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:device_token) { DeviceToken.create!(user: user, token: 'ExpoToken[del-sw]', platform: 'android') }
        let(:id) { device_token.id }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '401', '未登录或 Token 无效' do
        let(:Authorization) { 'Bearer invalid.token' }
        let(:id) { 1 }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end

        run_test!
      end

      response '404', 'Token 不存在' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:id) { 999999 }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end
  end
end
