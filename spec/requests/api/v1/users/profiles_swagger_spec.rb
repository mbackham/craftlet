# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'User Profile API', type: :request do
  let(:logto_sub)   { 'logto-profile-swagger-001' }
  let(:logto_email) { 'profile-swagger@example.com' }
  let!(:user) do
    create(:user,
           external_id: logto_sub,
           email: logto_email,
           nickname: 'SwaggerUser',
           locale: 'zh-CN',
           country_code: 'CN')
  end
  let(:valid_claims) do
    Auth::TokenClaims.new(
      sub: logto_sub, email: logto_email,
      name: 'Swagger User', phone_number: nil, raw: {}
    )
  end

  path '/api/v1/users/profile' do
    get '获取当前用户资料' do
      tags '用户'
      description '返回当前登录用户的完整资料。需要 Logto JWT 认证。'
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
                     id:           { type: :integer },
                     email:        { type: :string, format: 'email' },
                     nickname:     { type: :string, nullable: true },
                     locale:       { type: :string, example: 'zh-CN' },
                     country_code: { type: :string, example: 'CN', nullable: true },
                     status:       { type: :string, enum: %w[active suspended disabled] },
                     is_merchant:  { type: :boolean },
                     created_at:   { type: :string, format: 'date-time' }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '401', '未登录或 Token 无效' do
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

        let(:Authorization) { 'Bearer invalid.token' }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end

        run_test!
      end
    end

    patch '更新当前用户资料' do
      tags '用户'
      description '更新当前登录用户的资料（locale、country_code、nickname、avatar_key）。需要 Logto JWT 认证。'
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
          user: {
            type: :object,
            properties: {
              nickname:     { type: :string, description: '昵称' },
              locale:       { type: :string, description: '语言偏好，如 zh-CN、en' },
              country_code: { type: :string, description: '地区代码，如 CN、INTL' },
              avatar_key:   { type: :string, description: 'S3 对象 Key（头像）' }
            }
          }
        },
        required: %w[user]
      }

      response '200', '更新成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:           { type: :integer },
                     email:        { type: :string },
                     nickname:     { type: :string, nullable: true },
                     locale:       { type: :string },
                     country_code: { type: :string, nullable: true },
                     status:       { type: :string }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:body) { { user: { locale: 'en', nickname: 'Updated' } } }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '401', '未登录或 Token 无效' do
        let(:Authorization) { 'Bearer invalid.token' }
        let(:body) { { user: { locale: 'en' } } }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end

        run_test!
      end
    end
  end
end
