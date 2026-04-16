# frozen_string_literal: true

require 'swagger_helper'

# spec/requests/api/v1/coupons_swagger_spec.rb
#
# 优惠券模块 Swagger 文档
# 所有接口需要 Logto JWT 认证
#
# GET  /api/v1/coupons              — 我的优惠券列表
# GET  /api/v1/coupons/available    — 可用优惠券（下单时用）
# POST /api/v1/coupons/redeem       — 兑换码核销
# POST /api/v1/coupons/grant_new_user — 新用户发券
#
RSpec.describe 'Coupons API', type: :request do
  let(:logto_sub)   { 'logto-coupon-swagger-001' }
  let(:logto_email) { 'coupon-sw@example.com' }
  let!(:user)       { create(:user, external_id: logto_sub, email: logto_email) }

  let(:valid_claims) do
    Auth::TokenClaims.new(
      sub: logto_sub, email: logto_email,
      name: nil, phone_number: nil, raw: {}
    )
  end

  # 共享的优惠券 schema（单张）
  let(:coupon_schema) do
    {
      type: :object,
      properties: {
        id:         { type: :integer, example: 1 },
        code:       { type: :string,  example: 'CPN-ABC123', description: '优惠券实例唯一码' },
        status:     { type: :string,  enum: %w[unused used expired], example: 'unused' },
        grant_type: { type: :string,  enum: %w[new_user redeem manual], example: 'new_user' },
        granted_at: { type: :string,  format: 'date-time' },
        expires_at: { type: :string,  format: 'date-time', nullable: true },
        used_at:    { type: :string,  format: 'date-time', nullable: true },
        usable:     { type: :boolean, example: true, description: '当前是否可用（未过期且未使用）' },
        template: {
          type: :object,
          properties: {
            id:               { type: :integer, example: 10 },
            name:             { type: :string,  example: '新用户专享 20 元优惠券' },
            coupon_type:      { type: :string,  enum: %w[discount fixed_amount redeem_code], example: 'fixed_amount' },
            face_value:       { type: :string,  example: '20.0', description: '面值（固定减 N 元）或折扣率（0.8 = 八折）' },
            min_order_amount: { type: :string,  example: '100.0', description: '使用门槛：订单满 N 元可用' }
          },
          required: %w[id name coupon_type face_value min_order_amount]
        }
      },
      required: %w[id code status grant_type granted_at usable template]
    }
  end

  # ── 我的优惠券列表 ────────────────────────────────────────────────────────

  path '/api/v1/coupons' do
    get '我的优惠券列表' do
      tags '优惠券'
      description <<~DESC
        获取当前登录用户的所有优惠券，按发放时间倒序。
        - 需要 Logto JWT 认证
        - 支持 `?status=` 按状态过滤：`unused` / `used` / `expired`
        - ⚠️ 响应格式为裸数组（非标准 `{success, data}` 封装），前端直接读取数组
      DESC
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: 'Bearer <Logto JWT>'

      parameter name: :status,
                in: :query,
                type: :string,
                required: false,
                enum: %w[unused used expired],
                description: '按优惠券状态过滤'

      response '200', '获取成功' do
        schema type: :array,
               items: {
                 type: :object,
                 properties: {
                   id:         { type: :integer },
                   code:       { type: :string },
                   status:     { type: :string, enum: %w[unused used expired] },
                   grant_type: { type: :string },
                   granted_at: { type: :string, format: 'date-time' },
                   expires_at: { type: :string, format: 'date-time', nullable: true },
                   used_at:    { type: :string, format: 'date-time', nullable: true },
                   usable:     { type: :boolean },
                   template: {
                     type: :object,
                     properties: {
                       id:               { type: :integer },
                       name:             { type: :string },
                       coupon_type:      { type: :string },
                       face_value:       { type: :string },
                       min_order_amount: { type: :string }
                     }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }
        run_test!
      end

      response '401', '未登录' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 error:   { type: :object, properties: { message: { type: :string } } }
               }

        let(:Authorization) { 'Bearer invalid.token' }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end
        run_test!
      end
    end
  end

  # ── 可用优惠券（下单时） ─────────────────────────────────────────────────

  path '/api/v1/coupons/available' do
    get '可用优惠券列表（下单时调用）' do
      tags '优惠券'
      description <<~DESC
        获取当前用户可立即使用的优惠券（状态 `unused`，未过期）。
        - 可传 `?order_amount=` 按订单金额过滤（仅返回满足门槛的优惠券）
        - 需要 Logto JWT 认证
        - 用于创建订单时展示可用优惠券选择器
      DESC
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: 'Bearer <Logto JWT>'

      parameter name: :order_amount,
                in: :query,
                type: :string,
                required: false,
                description: '当前订单金额（如 "299.00"），用于过滤满足使用门槛的优惠券'

      response '200', '获取成功' do
        schema type: :array,
               items: {
                 type: :object,
                 properties: {
                   id:         { type: :integer },
                   code:       { type: :string },
                   status:     { type: :string, example: 'unused' },
                   usable:     { type: :boolean, example: true },
                   template: {
                     type: :object,
                     properties: {
                       name:             { type: :string,  example: '满100减20' },
                       face_value:       { type: :string,  example: '20.0' },
                       min_order_amount: { type: :string,  example: '100.0' }
                     }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }
        run_test!
      end

      response '401', '未登录' do
        let(:Authorization) { 'Bearer invalid.token' }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end
        run_test!
      end
    end
  end

  # ── 兑换码核销 ────────────────────────────────────────────────────────────

  path '/api/v1/coupons/redeem' do
    post '兑换码核销' do
      tags '优惠券'
      description <<~DESC
        用户输入兑换码（如活动码、礼品码）领取对应优惠券。
        - 需要 Logto JWT 认证
        - `code` 不区分大小写（服务端会转大写处理）
        - 兑换成功返回新领取的优惠券信息
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
          code: { type: :string, description: '兑换码（不区分大小写）', example: 'SPRING2026' }
        },
        required: %w[code]
      }

      response '201', '兑换成功' do
        schema type: :object,
               properties: {
                 id:         { type: :integer },
                 code:       { type: :string },
                 status:     { type: :string, example: 'unused' },
                 grant_type: { type: :string, example: 'redeem' },
                 granted_at: { type: :string, format: 'date-time' },
                 expires_at: { type: :string, format: 'date-time', nullable: true },
                 usable:     { type: :boolean, example: true },
                 template: {
                   type: :object,
                   properties: {
                     id:               { type: :integer },
                     name:             { type: :string },
                     coupon_type:      { type: :string },
                     face_value:       { type: :string },
                     min_order_amount: { type: :string }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:body) { { code: 'SPRING2026' } }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }
        run_test!
      end

      response '422', '兑换码无效或已使用' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: '兑换码无效' }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:body) { { code: '' } }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }
        run_test!
      end

      response '401', '未登录' do
        let(:Authorization) { 'Bearer invalid.token' }
        let(:body) { { code: 'TEST' } }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end
        run_test!
      end
    end
  end

  # ── 新用户发券 ────────────────────────────────────────────────────────────

  path '/api/v1/coupons/grant_new_user' do
    post '新用户注册发券' do
      tags '优惠券'
      description <<~DESC
        新用户完成注册后调用，自动发放所有配置了 `new_user` 规则的优惠券模板。
        - 需要 Logto JWT 认证
        - **建议在用户首次登录/注册成功后由客户端主动调用一次**
        - 若用户已领过新用户券，此接口返回空数组（幂等）
        - 发券失败（如已达到发放上限）会被忽略，不影响响应
      DESC
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: 'Bearer <Logto JWT>'

      response '201', '发券成功（可能为空数组，若无可用新用户券）' do
        schema type: :array,
               items: {
                 type: :object,
                 properties: {
                   id:         { type: :integer },
                   code:       { type: :string },
                   status:     { type: :string, example: 'unused' },
                   grant_type: { type: :string, example: 'new_user' },
                   granted_at: { type: :string, format: 'date-time' },
                   expires_at: { type: :string, format: 'date-time', nullable: true },
                   usable:     { type: :boolean, example: true },
                   template: {
                     type: :object,
                     properties: {
                       id:               { type: :integer },
                       name:             { type: :string, example: '新用户专享 20 元券' },
                       face_value:       { type: :string, example: '20.0' },
                       min_order_amount: { type: :string, example: '100.0' }
                     }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }
        run_test!
      end

      response '401', '未登录' do
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
