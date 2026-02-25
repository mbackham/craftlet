# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Users Sessions API', type: :request do
  path '/api/v1/users/sign_in' do
    post '用户登录' do
      tags '认证'
      description '使用邮箱和密码登录，返回 JWT Token'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, example: 'user@example.com', description: '用户邮箱' },
              password: { type: :string, example: 'password123', description: '用户密码' }
            },
            required: %w[email password]
          }
        },
        required: %w[user]
      }

      response '200', '登录成功' do
        schema type: :object,
               properties: {
                 user: {
                   type: :object,
                   properties: {
                     id: { type: :integer, description: '用户 ID' },
                     email: { type: :string, description: '用户邮箱' }
                   }
                 },
                 token: { type: :string, description: 'JWT Token' }
               }

        let(:body) { { user: { email: 'test@example.com', password: 'password' } } }
        run_test!
      end

      response '401', '登录失败（邮箱或密码错误）' do
        let(:body) { { user: { email: 'wrong@example.com', password: 'wrong' } } }
        run_test!
      end
    end
  end

  path '/api/v1/users/sign_out' do
    delete '用户登出' do
      tags '认证'
      description '注销当前用户的 JWT Token'
      security [Bearer: []]
      produces 'application/json'

      response '204', '登出成功' do
        let(:Authorization) { 'Bearer token' }
        run_test!
      end
    end
  end
end
