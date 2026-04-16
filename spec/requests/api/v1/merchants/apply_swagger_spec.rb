# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Merchant Apply & Status API', type: :request do
  let(:logto_sub)   { 'logto-m-apply-sw-001' }
  let(:logto_email) { 'apply-sw@example.com' }
  let!(:user)       { create(:user, external_id: logto_sub, email: logto_email) }

  let(:valid_claims) do
    Auth::TokenClaims.new(
      sub: logto_sub, email: logto_email,
      name: nil, phone_number: nil, raw: {}
    )
  end

  # 现有 GET /api/v1/merchant/status 已在 merchants_spec.rb 中有 swagger 文档
  # 此文件补充 POST /api/v1/merchant/apply

  path '/api/v1/merchant/apply' do
    post '提交商家入驻申请' do
      tags '商家'
      description <<~DESC
        普通用户提交入驻申请，创建 `MerchantProfile`，初始状态为 `submitted`，等待管理员审核。
        - 同一用户只能申请一次（重复提交返回 422）
        - 需要 Logto JWT 认证
      DESC
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
          merchant: {
            type: :object,
            properties: {
              shop_name:        { type: :string, description: '店铺名称（必填）' },
              license_file_key: { type: :string, description: '营业执照 OSS Key' },
              idcard_front_key: { type: :string, description: '身份证正面 OSS Key' },
              idcard_back_key:  { type: :string, description: '身份证背面 OSS Key' },
              bank_name:        { type: :string, description: '开户银行名称' },
              bank_branch:      { type: :string, description: '开户支行' },
              address_province: { type: :string, description: '省份' },
              address_city:     { type: :string, description: '城市' },
              address_district: { type: :string, description: '区县' },
              address_detail:   { type: :string, description: '详细地址' }
            },
            required: %w[shop_name]
          }
        },
        required: %w[merchant]
      }

      response '201', '申请提交成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:         { type: :integer },
                     status:     { type: :string, enum: %w[submitted], example: 'submitted' },
                     shop_name:  { type: :string },
                     created_at: { type: :string, format: 'date-time' }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:body) do
          { merchant: { shop_name: 'Swagger工坊', license_file_key: 'lic/sw.jpg' } }
        end
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '401', '未登录或 Token 无效' do
        let(:Authorization) { 'Bearer invalid.token' }
        let(:body) { { merchant: { shop_name: '测试' } } }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end

        run_test!
      end

      response '422', '重复申请或参数验证失败' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 error: {
                   type: :object,
                   properties: {
                     code:    { type: :string, enum: %w[already_applied validation_error] },
                     message: { type: :string }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:body) { { merchant: { shop_name: '' } } }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end
  end
end
