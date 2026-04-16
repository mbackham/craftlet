# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Orders API (Consumer)', type: :request do
  let(:logto_sub)      { 'logto-order-swagger-001' }
  let(:logto_email)    { 'order-swagger@example.com' }
  let!(:customer)      { create(:user, external_id: logto_sub, email: logto_email) }
  let!(:merchant_user) { create(:user, email: 'order-sw-merchant@example.com') }

  let(:valid_claims) do
    Auth::TokenClaims.new(
      sub: logto_sub, email: logto_email,
      name: nil, phone_number: nil, raw: {}
    )
  end

  def customer_uuid
    Order.id_to_uuid(customer.id)
  end

  def merchant_uuid
    Order.id_to_uuid(merchant_user.id)
  end

  path '/api/v1/orders' do
    get '消费者订单列表' do
      tags '订单'
      description '分页返回当前登录用户（消费者）的所有订单，按创建时间倒序排列。需要 Logto JWT 认证。'
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: 'Bearer <Logto JWT>'

      parameter name: :page,     in: :query, type: :integer, description: '页码（默认 1）'
      parameter name: :per_page, in: :query, type: :integer, description: '每页条数（默认 20）'

      response '200', '获取成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id:           { type: :integer },
                       order_no:     { type: :string, example: 'ORD20260416ABCDEF' },
                       status:       { type: :string, enum: %w[created paid accepted completed canceled refunded] },
                       total_amount: { type: :string, example: '299.0' },
                       currency:     { type: :string, example: 'CNY' },
                       created_at:   { type: :string, format: 'date-time' }
                     }
                   }
                 },
                 meta: {
                   type: :object,
                   properties: {
                     current_page: { type: :integer },
                     total_pages:  { type: :integer },
                     total_count:  { type: :integer },
                     per_page:     { type: :integer }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:page) { 1 }
        let(:per_page) { 20 }
        let!(:my_order) do
          create(:order, customer_id: customer_uuid, merchant_id: merchant_uuid, status: 'created')
        end
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '401', '未登录或 Token 无效' do
        let(:Authorization) { 'Bearer invalid.token' }
        let(:page) { 1 }
        let(:per_page) { 20 }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end

        run_test!
      end
    end

    post '创建订单' do
      tags '订单'
      description '消费者创建新订单。创建后状态为 created，等待支付。需要 Logto JWT 认证。'
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
          order: {
            type: :object,
            properties: {
              merchant_id:  { type: :string, description: '商家 UUID（格式：00000000-0000-0000-0000-XXXXXXXXXXXX）' },
              total_amount: { type: :string, description: '订单金额', example: '299.00' },
              currency:     { type: :string, description: '货币代码', example: 'CNY' }
            },
            required: %w[merchant_id total_amount currency]
          }
        },
        required: %w[order]
      }

      response '201', '订单创建成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:           { type: :integer },
                     order_no:     { type: :string },
                     status:       { type: :string, enum: %w[created] },
                     total_amount: { type: :string },
                     currency:     { type: :string },
                     created_at:   { type: :string, format: 'date-time' }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:body) do
          {
            order: {
              merchant_id:  merchant_uuid,
              total_amount: '299.00',
              currency:     'CNY'
            }
          }
        end
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '401', '未登录或 Token 无效' do
        let(:Authorization) { 'Bearer invalid.token' }
        let(:body) { { order: { merchant_id: merchant_uuid, total_amount: '100.00', currency: 'CNY' } } }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end

        run_test!
      end
    end
  end

  path '/api/v1/orders/{id}' do
    get '订单详情' do
      tags '订单'
      description '返回单个订单详情，包含订单项和支付记录。只有订单的消费者或商家可以查看。需要 Logto JWT 认证。'
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: 'Bearer <Logto JWT>'

      parameter name: :id, in: :path, type: :integer, required: true, description: '订单 ID'

      response '200', '获取成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:           { type: :integer },
                     order_no:     { type: :string },
                     status:       { type: :string },
                     total_amount: { type: :string },
                     currency:     { type: :string },
                     order_items:  { type: :array, items: { type: :object } },
                     payments:     { type: :array, items: { type: :object } },
                     created_at:   { type: :string, format: 'date-time' }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:order) do
          create(:order, customer_id: customer_uuid, merchant_id: merchant_uuid, status: 'created')
        end
        let(:id) { order.id }
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

      response '403', '无权查看此订单' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 error:   { type: :object, properties: { code: { type: :string }, message: { type: :string } } }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:other_order) { create(:order) }
        let(:id) { other_order.id }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '404', '订单不存在' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:id) { 999999 }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end
  end

  path '/api/v1/orders/{id}/cancel' do
    post '取消订单' do
      tags '订单'
      description '消费者取消自己的订单。只有 created 状态的订单可以取消，其他状态返回 422。需要 Logto JWT 认证。'
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: 'Bearer <Logto JWT>'

      parameter name: :id, in: :path, type: :integer, required: true, description: '订单 ID'

      response '200', '取消成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:     { type: :integer },
                     status: { type: :string, enum: %w[canceled] }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:order) do
          create(:order, customer_id: customer_uuid, merchant_id: merchant_uuid, status: 'created')
        end
        let(:id) { order.id }
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

      response '403', '无权操作此订单' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:other_order) { create(:order, status: 'created') }
        let(:id) { other_order.id }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '422', '当前状态无法取消（如已完成）' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 error: {
                   type: :object,
                   properties: {
                     code:    { type: :string, example: 'invalid_state' },
                     message: { type: :string }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:order) do
          create(:order, customer_id: customer_uuid, merchant_id: merchant_uuid, status: 'completed')
        end
        let(:id) { order.id }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end
  end
end
