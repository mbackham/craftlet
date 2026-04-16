# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Merchant Orders API', type: :request do
  let(:logto_sub)   { 'logto-m-ord-sw-001' }
  let(:logto_email) { 'm-ord-sw@example.com' }
  let!(:merchant)   { create(:user, external_id: logto_sub, email: logto_email) }
  let!(:profile)    { create(:merchant_profile, user: merchant, status: 'approved') }
  let!(:customer)   { create(:user, email: 'cust-ord-sw@example.com') }

  let(:valid_claims) do
    Auth::TokenClaims.new(
      sub: logto_sub, email: logto_email,
      name: nil, phone_number: nil, raw: {}
    )
  end

  def merchant_uuid; Order.id_to_uuid(merchant.id); end
  def customer_uuid; Order.id_to_uuid(customer.id); end

  def create_merchant_order(attrs = {})
    create(:order, { merchant_id: merchant_uuid, customer_id: customer_uuid }.merge(attrs))
  end

  path '/api/v1/merchant/orders' do
    get '商家订单列表' do
      tags '商家'
      description <<~DESC
        返回当前商家（已审核通过）的订单列表，按创建时间倒序排列，支持状态筛选和分页。
        需要 Logto JWT 认证，且商家 `merchant_profile.status` 必须为 `approved`。
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
                description: '状态过滤（created/paid/accepted/producing/delivered/completed/canceled）'

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
                       id:               { type: :integer },
                       order_no:         { type: :string },
                       status:           { type: :string },
                       total_amount:     { type: :string },
                       currency:         { type: :string },
                       customer_nickname:{ type: :string, nullable: true },
                       paid_at:          { type: :string, format: 'date-time', nullable: true },
                       created_at:       { type: :string, format: 'date-time' }
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
        let(:status) { nil }
        let(:page) { 1 }
        let(:per_page) { 20 }
        let!(:order) { create_merchant_order(status: 'paid') }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '401', '未登录或 Token 无效' do
        let(:Authorization) { 'Bearer invalid.token' }
        let(:status) { nil }
        let(:page) { 1 }
        let(:per_page) { 20 }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end

        run_test!
      end

      response '403', '商家账号未审核通过' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 error: {
                   type: :object,
                   properties: {
                     code:    { type: :string, example: 'merchant_not_approved' },
                     message: { type: :string }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:status) { nil }
        let(:page) { 1 }
        let(:per_page) { 20 }
        before do
          profile.update!(status: 'submitted')
          allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims)
        end

        run_test!
      end
    end
  end

  path '/api/v1/merchant/orders/{id}' do
    get '商家订单详情' do
      tags '商家'
      description '返回商家自己订单的详情，含订单项列表。需要 Logto JWT 认证且 merchant_profile 已审核。'
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header, type: :string, required: true, description: 'Bearer <Logto JWT>'

      parameter name: :id, in: :path, type: :integer, required: true, description: '订单 ID'

      response '200', '获取成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:               { type: :integer },
                     order_no:         { type: :string },
                     status:           { type: :string },
                     total_amount:     { type: :string },
                     currency:         { type: :string },
                     customer_nickname:{ type: :string, nullable: true },
                     order_items:      { type: :array, items: { type: :object } },
                     accepted_at:      { type: :string, format: 'date-time', nullable: true },
                     producing_at:     { type: :string, format: 'date-time', nullable: true },
                     delivered_at:     { type: :string, format: 'date-time', nullable: true },
                     completed_at:     { type: :string, format: 'date-time', nullable: true }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:order) { create_merchant_order(status: 'paid') }
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

      response '404', '订单不存在或不属于当前商家' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:other_order) { create(:order) }
        let(:id) { other_order.id }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end
  end

  path '/api/v1/merchant/orders/{id}/accept' do
    post '接单（paid → accepted）' do
      tags '商家'
      description <<~DESC
        商家接受订单，将状态从 `paid` 转为 `accepted`。
        - 前置条件：订单状态必须为 `paid`
        - 前置条件：商家 `merchant_profile.status == approved` 且 `user.status == active`（AASM guard `merchant_active?`）
        需要 Logto JWT 认证。
      DESC
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header, type: :string, required: true, description: 'Bearer <Logto JWT>'

      parameter name: :id, in: :path, type: :integer, required: true, description: '订单 ID'

      response '200', '接单成功，状态变为 accepted' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:          { type: :integer },
                     status:      { type: :string, enum: %w[accepted] },
                     accepted_at: { type: :string, format: 'date-time', nullable: true }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:order) { create_merchant_order(status: 'paid') }
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

      response '404', '订单不存在或不属于当前商家' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:other_order) { create(:order, status: 'paid') }
        let(:id) { other_order.id }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '422', '订单状态不允许接单（如已取消）' do
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
        let!(:order) { create_merchant_order(status: 'created') }
        let(:id) { order.id }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end
  end

  path '/api/v1/merchant/orders/{id}/start_producing' do
    post '开始制作（accepted → producing）' do
      tags '商家'
      description '商家开始制作/服务，将订单状态从 `accepted` 转为 `producing`。需要 Logto JWT 认证。'
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header, type: :string, required: true, description: 'Bearer <Logto JWT>'

      parameter name: :id, in: :path, type: :integer, required: true, description: '订单 ID'

      response '200', '状态变为 producing' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:           { type: :integer },
                     status:       { type: :string, enum: %w[producing] },
                     producing_at: { type: :string, format: 'date-time', nullable: true }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:order) { create_merchant_order(status: 'accepted') }
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

      response '404', '订单不存在或不属于当前商家' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:other_order) { create(:order, status: 'accepted') }
        let(:id) { other_order.id }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '422', '订单状态不允许此操作' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:order) { create_merchant_order(status: 'paid') }
        let(:id) { order.id }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end
  end

  path '/api/v1/merchant/orders/{id}/deliver' do
    post '发货/完成服务（producing → delivered）' do
      tags '商家'
      description '商家完成制作并发货/交付，将订单状态从 `producing` 转为 `delivered`。需要 Logto JWT 认证。'
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header, type: :string, required: true, description: 'Bearer <Logto JWT>'

      parameter name: :id, in: :path, type: :integer, required: true, description: '订单 ID'

      response '200', '状态变为 delivered' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:          { type: :integer },
                     status:      { type: :string, enum: %w[delivered] },
                     delivered_at:{ type: :string, format: 'date-time', nullable: true }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:order) { create_merchant_order(status: 'producing') }
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

      response '404', '订单不存在或不属于当前商家' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:other_order) { create(:order, status: 'producing') }
        let(:id) { other_order.id }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '422', '订单状态不允许此操作' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:order) { create_merchant_order(status: 'accepted') }
        let(:id) { order.id }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end
  end
end
