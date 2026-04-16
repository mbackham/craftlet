# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Notifications API', type: :request do
  let(:logto_sub)   { 'logto-notif-swagger-001' }
  let(:logto_email) { 'notif-swagger@example.com' }
  let!(:user)       { create(:user, external_id: logto_sub, email: logto_email) }

  let(:valid_claims) do
    Auth::TokenClaims.new(
      sub: logto_sub, email: logto_email,
      name: nil, phone_number: nil, raw: {}
    )
  end

  def create_notification(attrs = {})
    Notification.create!({
      user: user,
      title: '测试通知',
      body: '这是一条测试通知',
      notification_type: 'order_accepted'
    }.merge(attrs))
  end

  path '/api/v1/notifications' do
    get '通知列表' do
      tags '通知'
      description '分页返回当前用户的站内通知，按创建时间倒序排列。响应中包含已读/未读状态。需要 Logto JWT 认证。'
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
                       id:                { type: :integer },
                       title:             { type: :string },
                       body:              { type: :string },
                       notification_type: {
                         type: :string,
                         enum: %w[order_accepted order_rejected order_completed order_canceled payment_success system],
                         description: '通知类型'
                       },
                       read:       { type: :boolean, description: '是否已读' },
                       read_at:    { type: :string, format: 'date-time', nullable: true },
                       data:       { type: :object, nullable: true, additionalProperties: true, description: '附加业务数据（如 order_id）' },
                       created_at: { type: :string, format: 'date-time' }
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
        let!(:notif) { create_notification }
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

  path '/api/v1/notifications/mark_read' do
    patch '批量标记通知已读' do
      tags '通知'
      description <<~DESC
        将指定通知标记为已读。
        - 传入 `ids` 数组：只标记指定 ID 的通知
        - 不传 `ids`（或传空数组）：标记当前用户所有未读通知为已读
        - 跨用户隔离：只处理属于当前用户的通知，其他用户的 ID 会被忽略
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
          ids: {
            type: :array,
            items: { type: :integer },
            description: '要标记已读的通知 ID 列表（不传则标记全部未读）'
          }
        }
      }

      response '200', '标记成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     marked_count: { type: :integer, description: '本次实际标记已读的数量' }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:notif1) { create_notification }
        let!(:notif2) { create_notification }
        let(:body) { { ids: [notif1.id, notif2.id] } }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '200', '全部标记已读（不传 ids）' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     marked_count: { type: :integer }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:notif) { create_notification }
        let(:body) { {} }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '401', '未登录或 Token 无效' do
        let(:Authorization) { 'Bearer invalid.token' }
        let(:body) { {} }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end

        run_test!
      end
    end
  end
end
