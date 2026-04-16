# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Payments API', type: :request do
  let(:logto_sub)      { 'logto-pay-swagger-001' }
  let(:logto_email)    { 'pay-swagger@example.com' }
  let!(:customer)      { create(:user, external_id: logto_sub, email: logto_email) }
  let!(:merchant_user) { create(:user, email: 'pay-sw-merchant@example.com') }

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

  let!(:order) do
    create(:order,
           customer_id: customer_uuid,
           merchant_id: merchant_uuid,
           status: 'created',
           total_amount: '188.00')
  end

  path '/api/v1/payments' do
    post '创建支付单' do
      tags '支付'
      description <<~DESC
        为订单创建支付单，返回 App 端调起支付所需的参数（微信/支付宝）。
        - 订单状态必须为 `created`，否则返回 422
        - 只有订单的消费者可以发起支付
        - 支持渠道：`wechat`（微信支付）、`alipay`（支付宝）
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

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          order_id: { type: :integer, description: '订单 ID' },
          channel:  { type: :string, enum: %w[wechat alipay], description: '支付渠道' }
        },
        required: %w[order_id channel]
      }

      response '201', '支付单创建成功，返回调起参数' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:                { type: :integer, description: '支付单 ID' },
                     channel:           { type: :string, enum: %w[wechat alipay] },
                     amount:            { type: :string, example: '188.0' },
                     status:            { type: :string, enum: %w[pending] },
                     provider_trade_no: { type: :string, nullable: true },
                     pay_params: {
                       type: :object,
                       description: 'App 调起支付所需参数（微信：prepay_id 等；支付宝：order_string）',
                       additionalProperties: true
                     },
                     created_at: { type: :string, format: 'date-time' }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:body) { { order_id: order.id, channel: 'wechat' } }
        before do
          allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims)
          allow_any_instance_of(Payments::WechatProvider)
            .to receive(:create_payment)
            .and_return({
                          success: true,
                          provider_trade_no: "WX#{SecureRandom.hex(8).upcase}",
                          raw: { prepay_id: 'wx_prepay_swagger', timeStamp: '1234567890' }
                        })
        end

        run_test!
      end

      response '401', '未登录或 Token 无效' do
        let(:Authorization) { 'Bearer invalid.token' }
        let(:body) { { order_id: order.id, channel: 'wechat' } }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end

        run_test!
      end

      response '403', '无权为此订单支付' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 error:   { type: :object, properties: { code: { type: :string }, message: { type: :string } } }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:other_order) { create(:order, status: 'created') }
        let(:body) { { order_id: other_order.id, channel: 'wechat' } }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '422', '不支持的支付渠道或订单状态不允许支付' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 error: {
                   type: :object,
                   properties: {
                     code:    { type: :string, enum: %w[unsupported_channel invalid_order_status payment_create_failed] },
                     message: { type: :string }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:body) { { order_id: order.id, channel: 'bitcoin' } }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end
  end

  path '/api/v1/payments/{id}/status' do
    get '查询支付状态' do
      tags '支付'
      description '轮询查询支付单当前状态。App 端调起支付后可轮询此接口确认支付结果。只有订单的消费者可以查询。需要 Logto JWT 认证。'
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: 'Bearer <Logto JWT>'

      parameter name: :id, in: :path, type: :integer, required: true, description: '支付单 ID'

      response '200', '查询成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:      { type: :integer },
                     status:  { type: :string, enum: %w[pending paid failed refunded] },
                     channel: { type: :string, enum: %w[wechat alipay] },
                     amount:  { type: :string },
                     paid_at: { type: :string, format: 'date-time', nullable: true }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:payment) do
          create(:payment, order: order, channel: 'wechat', status: 'paid', paid_at: Time.current)
        end
        let(:id) { payment.id }
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

      response '403', '无权查看此支付单' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:other_payment) { create(:payment) }
        let(:id) { other_payment.id }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '404', '支付单不存在' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:id) { 999999 }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end
  end
end
