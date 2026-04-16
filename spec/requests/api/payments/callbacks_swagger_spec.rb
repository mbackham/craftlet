# frozen_string_literal: true

require 'swagger_helper'

# 支付回调 API — 由微信/支付宝服务器主动调用，无需用户 JWT 认证
# Payment Callback API — called by WeChat/Alipay servers, no JWT auth required
#
# ⚠️ 已知限制 / Known Limitations:
#   KI-W2-01: 真实签名验证（微信 RSA-SHA256 / 支付宝 RSA2）因营业执照未到位而处于 stub 模式。
#             目前 verify_callback 在测试/mock 模式下始终返回 true。
#             生产上线前必须启用真实签名验证。
#
#   KI-W2-01: Real signature verification (WeChat RSA-SHA256 / Alipay RSA2) is in stub
#             mode pending business license. verify_callback always returns true in mock mode.
#             Must enable real verification before production launch.
#
RSpec.describe 'Payment Callbacks API', type: :request do
  let(:order) do
    Order.create!(
      order_no:     "ORD-SW-CB-#{SecureRandom.hex(4)}",
      customer_id:  SecureRandom.uuid,
      merchant_id:  SecureRandom.uuid,
      status:       'paid',
      total_amount: 100.00,
      currency:     'CNY'
    )
  end

  let(:payment) do
    Payment.create!(
      order:             order,
      channel:           'wechat',
      status:            'paid',
      amount:            100.00,
      currency:          'CNY',
      provider_trade_no: "WX_TRADE_#{SecureRandom.hex(6).upcase}",
      idempotency_key:   "pay_#{SecureRandom.hex(8)}"
    )
  end

  let(:refund_no) { "WXR_MOCK_#{SecureRandom.hex(8).upcase}" }

  let!(:refund) do
    Refund.create!(
      order:              order,
      payment:            payment,
      amount:             100.00,
      reason:             'customer_request',
      status:             'pending',
      idempotency_key:    "ref_#{SecureRandom.hex(8)}",
      provider_refund_no: refund_no
    )
  end

  path '/api/payments/callbacks/wechat' do
    post '微信支付回调' do
      tags '支付回调'
      description <<~DESC
        接收微信支付退款结果回调通知。由微信服务器主动 POST 调用，**无需用户 JWT 认证**。

        **请求格式**：JSON Body

        **响应格式**：JSON `{"code": "SUCCESS"}` 或 `{"code": "FAIL"}`（微信要求的格式）

        **幂等性**：重复回调返回 200 SUCCESS，不重复处理。

        ⚠️ **KI-W2-01**：当前签名验证处于 stub 模式（营业执照未到位）。生产前需启用真实 RSA-SHA256 验证。
      DESC
      consumes 'application/json'
      produces 'application/json'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          refund_id:      { type: :string, description: '微信退款单号（provider_refund_no）' },
          out_refund_no:  { type: :string, description: '商户退款单号（idempotency_key）' },
          refund_fee:     { type: :integer, description: '退款金额（分）' }
        },
        required: %w[refund_id out_refund_no refund_fee]
      }

      response '200', '处理成功（含幂等重复回调）' do
        schema type: :object,
               properties: {
                 code: { type: :string, enum: %w[SUCCESS], description: '微信要求的成功标识' }
               }

        let(:body) do
          {
            refund_id:    refund_no,
            out_refund_no: refund.idempotency_key,
            refund_fee:   10000
          }
        end

        run_test!
      end

      response '400', '请求缺少必要字段（如 refund_id）' do
        schema type: :object,
               properties: {
                 code:    { type: :string, enum: %w[FAIL] },
                 message: { type: :string }
               }

        let(:body) { { other_field: 'value' } }

        run_test!
      end

      response '422', '未找到对应退款单（refund_id 不存在）' do
        let(:body) do
          {
            refund_id:    'WXR_UNKNOWN_XXXXX',
            out_refund_no: 'ref_unknown',
            refund_fee:   10000
          }
        end

        run_test!
      end
    end
  end

  path '/api/payments/callbacks/alipay' do
    post '支付宝回调' do
      tags '支付回调'
      description <<~DESC
        接收支付宝退款结果回调通知。由支付宝服务器主动 POST 调用，**无需用户 JWT 认证**。

        **请求格式**：Form Data（application/x-www-form-urlencoded）

        **响应格式**：纯文本 `success` 或 `fail`（支付宝要求的格式）

        **幂等性**：重复回调返回 200 success，不重复处理。

        ⚠️ **KI-W2-01**：当前签名验证处于 stub 模式（营业执照未到位）。生产前需启用真实 RSA2 验证。
      DESC
      consumes 'application/x-www-form-urlencoded'
      produces 'text/plain'

      parameter name: :notify_type,    in: :formData, type: :string, description: '通知类型，如 refund_resultNotify'
      parameter name: :out_request_no, in: :formData, type: :string, description: '退款单 provider_refund_no'
      parameter name: :trade_no,       in: :formData, type: :string, description: '支付宝交易号'
      parameter name: :refund_fee,     in: :formData, type: :string, description: '退款金额（元）'

      response '200', "处理成功，响应体为纯文本 'success'" do
        schema type: :string, example: 'success'

        let(:notify_type)    { 'refund_resultNotify' }
        let(:out_request_no) { refund_no }
        let(:trade_no)       { payment.provider_trade_no }
        let(:refund_fee)     { '100.00' }

        # 使用支付宝 channel 的 payment 和 refund
        before do
          payment.update!(channel: 'alipay')
          refund.update!(provider_refund_no: refund_no)
        end

        run_test!
      end

      response '400', "缺少必要字段，响应体为纯文本 'fail'" do
        schema type: :string, example: 'fail'

        let(:notify_type)    { 'refund_resultNotify' }
        let(:out_request_no) { nil }
        let(:trade_no)       { nil }
        let(:refund_fee)     { nil }

        run_test!
      end

      response '422', "未找到对应退款单，响应体为纯文本 'fail'" do
        schema type: :string, example: 'fail'

        let(:notify_type)    { 'refund_resultNotify' }
        let(:out_request_no) { 'ALIR_UNKNOWN' }
        let(:trade_no)       { 'trade_unknown' }
        let(:refund_fee)     { '100.00' }

        run_test!
      end
    end
  end
end
