# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Merchant Profile & Dashboard & Settlements API', type: :request do
  let(:logto_sub)   { 'logto-m-misc-sw-001' }
  let(:logto_email) { 'm-misc-sw@example.com' }
  let!(:merchant)   { create(:user, external_id: logto_sub, email: logto_email) }
  let!(:profile) do
    create(:merchant_profile, user: merchant, status: 'approved',
           shop_name: 'Swagger工坊', address_province: '广东省', address_city: '深圳市')
  end
  let!(:other_merchant) { create(:user, email: 'other-misc-sw@example.com') }
  let!(:other_profile)  { create(:merchant_profile, user: other_merchant) }

  let(:valid_claims) do
    Auth::TokenClaims.new(
      sub: logto_sub, email: logto_email,
      name: nil, phone_number: nil, raw: {}
    )
  end

  # ── 商家资料管理 ────────────────────────────────────────────────────────────

  path '/api/v1/merchant/profile' do
    get '查看商家自己的资料' do
      tags '商家'
      description '返回当前商家的完整资料，含脱敏银行账号和地址信息。需要 Logto JWT 认证。'
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header, type: :string, required: true, description: 'Bearer <Logto JWT>'

      response '200', '获取成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:                    { type: :integer },
                     status:                { type: :string },
                     shop_name:             { type: :string },
                     full_address:          { type: :string, nullable: true },
                     address_province:      { type: :string, nullable: true },
                     address_city:          { type: :string, nullable: true },
                     address_district:      { type: :string, nullable: true },
                     address_detail:        { type: :string, nullable: true },
                     bank_name:             { type: :string, nullable: true },
                     bank_branch:           { type: :string, nullable: true },
                     masked_bank_account_no:{ type: :string, nullable: true, description: '脱敏银行卡号' },
                     license_file_key:      { type: :string, nullable: true },
                     idcard_front_key:      { type: :string, nullable: true },
                     idcard_back_key:       { type: :string, nullable: true },
                     deposit_amount:        { type: :string, nullable: true },
                     approved_at:           { type: :string, format: 'date-time', nullable: true },
                     created_at:            { type: :string, format: 'date-time' }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '401', '未登录或 Token 无效' do
        let(:Authorization) { 'Bearer invalid.token' }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end

        run_test!
      end

      response '404', '当前用户无商家资料（未申请入驻）' do
        let(:no_profile_user) { create(:user, external_id: 'logto-np-misc', email: 'np-misc@ex.com') }
        let(:no_profile_claims) do
          Auth::TokenClaims.new(sub: 'logto-np-misc', email: 'np-misc@ex.com',
                                name: nil, phone_number: nil, raw: {})
        end
        let(:Authorization) { 'Bearer no-profile.token' }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(no_profile_claims) }

        run_test!
      end
    end

    patch '更新商家自己的资料' do
      tags '商家'
      description '更新商家可编辑字段（店铺名、银行信息、地址等）。需要 Logto JWT 认证。'
      security [Bearer: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization,
                in: :header, type: :string, required: true, description: 'Bearer <Logto JWT>'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          merchant: {
            type: :object,
            properties: {
              shop_name:        { type: :string },
              bank_name:        { type: :string },
              bank_branch:      { type: :string },
              address_province: { type: :string },
              address_city:     { type: :string },
              address_district: { type: :string },
              address_detail:   { type: :string }
            }
          }
        },
        required: %w[merchant]
      }

      response '200', '更新成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:        { type: :integer },
                     shop_name: { type: :string },
                     status:    { type: :string }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:body) { { merchant: { shop_name: '新店铺名', bank_name: '建设银行' } } }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '401', '未登录或 Token 无效' do
        let(:Authorization) { 'Bearer invalid.token' }
        let(:body) { { merchant: { shop_name: '新名' } } }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end

        run_test!
      end

      response '422', '参数验证失败（如 shop_name 为空）' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:body) { { merchant: { shop_name: '' } } }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end
  end

  # ── 商家看板 ──────────────────────────────────────────────────────────────

  path '/api/v1/merchant/dashboard' do
    get '商家数据看板' do
      tags '商家'
      description <<~DESC
        返回商家经营数据汇总，包括：今日订单数、各状态订单计数、本月营业额、累计完成订单数等。
        需要 Logto JWT 认证，且商家 `merchant_profile.status` 必须为 `approved`。
      DESC
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header, type: :string, required: true, description: 'Bearer <Logto JWT>'

      response '200', '看板数据获取成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     today_orders_count:    { type: :integer, description: '今日新增订单数' },
                     pending_accept_count:  { type: :integer, description: '待接单数（paid 状态）' },
                     producing_count:       { type: :integer, description: '制作中订单数' },
                     delivering_count:      { type: :integer, description: '待确认收货数（delivered 状态）' },
                     this_month_completed:  { type: :integer, description: '本月已完成订单数' },
                     this_month_revenue:    { type: :string,  description: '本月营业额（已完成订单合计）' },
                     total_completed_count: { type: :integer, description: '累计完成订单总数' },
                     merchant_status:       { type: :string,  description: '商家审核状态' }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '401', '未登录或 Token 无效' do
        let(:Authorization) { 'Bearer invalid.token' }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end

        run_test!
      end

      response '403', '商家账号未审核通过' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        before do
          profile.update!(status: 'submitted')
          allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims)
        end

        run_test!
      end
    end
  end

  # ── 结算查询 ──────────────────────────────────────────────────────────────

  path '/api/v1/merchant/settlements' do
    get '商家结算单列表' do
      tags '商家'
      description '分页返回当前商家的结算单列表，按创建时间倒序。需要 Logto JWT 认证。'
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header, type: :string, required: true, description: 'Bearer <Logto JWT>'

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
                       id:                  { type: :integer },
                       settlement_no:       { type: :string, example: 'ST202604010001' },
                       status:              { type: :string, enum: %w[pending_review approved paid_out confirmed rejected failed funds_frozen] },
                       period_start:        { type: :string, format: 'date' },
                       period_end:          { type: :string, format: 'date' },
                       total_order_amount:  { type: :string },
                       total_refund_amount: { type: :string },
                       net_amount:          { type: :string },
                       confirmed_at:        { type: :string, format: 'date-time', nullable: true },
                       created_at:          { type: :string, format: 'date-time' }
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
        let!(:settlement) do
          create(:settlement, merchant_profile: profile,
                 period_start: 30.days.ago.to_date, period_end: 23.days.ago.to_date)
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
  end

  path '/api/v1/merchant/settlements/{id}' do
    get '结算单详情' do
      tags '商家'
      description '返回指定结算单详情，含明细金额（保证金扣款、违约金、实际结算金额）。只能查看自己的结算单。需要 Logto JWT 认证。'
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header, type: :string, required: true, description: 'Bearer <Logto JWT>'

      parameter name: :id, in: :path, type: :integer, required: true, description: '结算单 ID'

      response '200', '获取成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:                  { type: :integer },
                     settlement_no:       { type: :string },
                     status:              { type: :string },
                     period_start:        { type: :string, format: 'date' },
                     period_end:          { type: :string, format: 'date' },
                     total_order_amount:  { type: :string },
                     total_refund_amount: { type: :string },
                     deposit_deduction:   { type: :string, nullable: true, description: '保证金扣款' },
                     penalty_amount:      { type: :string, nullable: true, description: '违约金' },
                     net_amount:          { type: :string, description: '实际结算金额' },
                     payout_reference:    { type: :string, nullable: true, description: '打款凭证号' },
                     failure_reason:      { type: :string, nullable: true },
                     frozen_reason:       { type: :string, nullable: true },
                     paid_out_at:         { type: :string, format: 'date-time', nullable: true },
                     confirmed_at:        { type: :string, format: 'date-time', nullable: true }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:settlement) do
          create(:settlement, :confirmed, merchant_profile: profile,
                 period_start: 60.days.ago.to_date, period_end: 53.days.ago.to_date)
        end
        let(:id) { settlement.id }
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

      response '404', '结算单不存在或不属于当前商家' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:other_settlement) do
          create(:settlement, merchant_profile: other_profile,
                 period_start: 90.days.ago.to_date, period_end: 83.days.ago.to_date)
        end
        let(:id) { other_settlement.id }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end
  end
end
