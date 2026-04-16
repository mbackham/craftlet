# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Bids API', type: :request do
  let(:logto_sub)   { 'logto-bid-swagger-001' }
  let(:logto_email) { 'bidder-swagger@example.com' }
  let!(:bidder)   { create(:user, external_id: logto_sub, email: logto_email) }
  let!(:customer) { create(:user, email: 'bid-sw-customer@example.com') }

  let(:valid_claims) do
    Auth::TokenClaims.new(
      sub: logto_sub, email: logto_email,
      name: nil, phone_number: nil, raw: {}
    )
  end

  let!(:order) do
    create(:order,
           customer_id: Order.id_to_uuid(customer.id),
           merchant_id: Order.id_to_uuid(bidder.id),
           status: 'created')
  end

  path '/api/v1/orders/{order_id}/bids' do
    get '查看订单竞价列表' do
      tags '竞价'
      description <<~DESC
        返回指定订单的所有报价列表。
        **权限**：只有订单的消费者（customer）可以查看报价列表，商家（bidder）查看会返回 403。
        需要 Logto JWT 认证。
      DESC
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: 'Bearer <Logto JWT>'

      parameter name: :order_id, in: :path, type: :integer, required: true, description: '订单 ID'

      response '200', '获取成功（仅限订单消费者）' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id:         { type: :integer },
                       amount:     { type: :string, example: '250.0' },
                       status:     { type: :string, enum: %w[pending accepted rejected] },
                       message:    { type: :string, nullable: true },
                       created_at: { type: :string, format: 'date-time' }
                     }
                   }
                 }
               }

        # 消费者登录才能查看
        let(:customer_claims) do
          Auth::TokenClaims.new(
            sub: 'logto-bid-sw-customer', email: customer.email,
            name: nil, phone_number: nil, raw: {}
          )
        end
        let(:Authorization) { 'Bearer customer.valid.token' }
        let(:order_id) { order.id }
        let!(:bid) do
          Bid.create!(order: order, bidder_id: Bid.id_to_uuid(bidder.id), amount: 250, status: 'pending')
        end
        before do
          customer.update!(external_id: 'logto-bid-sw-customer')
          allow(Auth::JwtVerifier).to receive(:call).and_return(customer_claims)
        end

        run_test!
      end

      response '401', '未登录或 Token 无效' do
        let(:Authorization) { 'Bearer invalid.token' }
        let(:order_id) { order.id }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end

        run_test!
      end

      response '403', '当前用户不是此订单的消费者' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 error:   { type: :object, properties: { code: { type: :string }, message: { type: :string } } }
               }

        # 用 bidder 身份登录（非消费者）
        let(:Authorization) { 'Bearer bidder.valid.token' }
        let(:order_id) { order.id }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end

    post '提交报价' do
      tags '竞价'
      description <<~DESC
        商家对指定订单提交报价（竞价）。报价金额必须大于 0。
        需要 Logto JWT 认证。
      DESC
      security [Bearer: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: 'Bearer <Logto JWT>'

      parameter name: :order_id, in: :path, type: :integer, required: true, description: '订单 ID'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          amount:  { type: :string, description: '报价金额（必须 > 0）', example: '250.00' },
          message: { type: :string, description: '报价备注（可选）' }
        },
        required: %w[amount]
      }

      response '201', '报价提交成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:         { type: :integer },
                     amount:     { type: :string },
                     status:     { type: :string, enum: %w[pending] },
                     message:    { type: :string, nullable: true },
                     created_at: { type: :string, format: 'date-time' }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:order_id) { order.id }
        let(:body) { { amount: '250.00', message: '专业服务' } }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '401', '未登录或 Token 无效' do
        let(:Authorization) { 'Bearer invalid.token' }
        let(:order_id) { order.id }
        let(:body) { { amount: '250.00' } }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end

        run_test!
      end

      response '404', '订单不存在' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:order_id) { 999999 }
        let(:body) { { amount: '250.00' } }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '422', '报价金额无效（≤0）' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 error:   { type: :object, properties: { code: { type: :string }, message: { type: :string } } }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:order_id) { order.id }
        let(:body) { { amount: '0' } }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end
  end
end
