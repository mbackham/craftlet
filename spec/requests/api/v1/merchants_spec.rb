# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Merchants API', type: :request do
  path '/api/v1/merchant/status' do
    get '获取商家审核状态' do
      tags '商家'
      description '返回当前登录用户的商家入驻审核状态。需要 JWT 认证。'
      security [Bearer: []]
      produces 'application/json'

      response '200', '获取成功' do
        schema type: :object,
               properties: {
                 status: {
                   type: :string,
                   enum: %w[not_applied pending submitted approved rejected suspended],
                   description: '审核状态'
                 },
                 shop_name: { type: :string, nullable: true, description: '店铺名称' },
                 message: { type: :string, description: '状态说明' },
                 rejected_reason: { type: :string, nullable: true, description: '拒绝原因' },
                 approved_at: { type: :string, nullable: true, format: 'date-time', description: '通过时间' },
                 rejected_at: { type: :string, nullable: true, format: 'date-time', description: '拒绝时间' },
                 created_at: { type: :string, nullable: true, format: 'date-time', description: '申请时间' }
               }

        let(:Authorization) { 'Bearer token' }
        run_test!
      end

      response '401', '未登录或 Token 无效' do
        run_test!
      end
    end
  end
end
