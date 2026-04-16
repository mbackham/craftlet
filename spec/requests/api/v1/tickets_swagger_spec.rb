# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Tickets API', type: :request do
  let(:logto_sub)   { 'logto-ticket-sw-001' }
  let(:logto_email) { 'ticket-sw@example.com' }
  let!(:user)       { create(:user, external_id: logto_sub, email: logto_email) }

  let(:valid_claims) do
    Auth::TokenClaims.new(
      sub: logto_sub, email: logto_email,
      name: nil, phone_number: nil, raw: {}
    )
  end

  # 创建属于当前用户的工单
  def create_my_ticket(attrs = {})
    ticket = create(:ticket, attrs)
    ticket.update_columns(
      creator_id:   Ticket.id_to_uuid(user.id),
      creator_type: 'User'
    )
    ticket
  end

  # ── GET /api/v1/tickets ──────────────────────────────────────────────────

  path '/api/v1/tickets' do
    get '工单列表' do
      tags '工单'
      description <<~DESC
        返回当前登录用户创建的工单列表，按创建时间倒序排列，支持分页。
        需要 Logto JWT 认证。
      DESC
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
                       id:          { type: :integer },
                       ticket_no:   { type: :string, example: 'TK-20260416-0001' },
                       subject:     { type: :string },
                       status:      { type: :string, enum: %w[open assigned in_progress resolved closed] },
                       category:    { type: :string, enum: %w[general payment order merchant other] },
                       priority:    { type: :string, enum: %w[low normal high urgent] },
                       created_at:  { type: :string, format: 'date-time' },
                       assigned_at: { type: :string, format: 'date-time', nullable: true },
                       resolved_at: { type: :string, format: 'date-time', nullable: true },
                       closed_at:   { type: :string, format: 'date-time', nullable: true }
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
        let!(:ticket) { create_my_ticket }
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

    post '创建工单' do
      tags '工单'
      description <<~DESC
        用户提交新工单，初始状态为 `open`，等待客服分配处理。
        - category 可选值：general / payment / order / merchant / other
        - priority 可选值：low / normal / high / urgent
        - 创建成功后会触发站内通知
        需要 Logto JWT 认证。
      DESC
      security [Bearer: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization,
                in: :header, type: :string, required: true, description: 'Bearer <Logto JWT>'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          ticket: {
            type: :object,
            properties: {
              subject:     { type: :string, description: '工单主题（必填）' },
              description: { type: :string, description: '详细描述' },
              category:    { type: :string, enum: %w[general payment order merchant other], description: '工单类别' },
              priority:    { type: :string, enum: %w[low normal high urgent], description: '优先级' }
            },
            required: %w[subject]
          }
        },
        required: %w[ticket]
      }

      response '201', '工单创建成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:         { type: :integer },
                     ticket_no:  { type: :string },
                     subject:    { type: :string },
                     status:     { type: :string, enum: %w[open] },
                     category:   { type: :string },
                     priority:   { type: :string },
                     created_at: { type: :string, format: 'date-time' }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:body) do
          { ticket: { subject: '订单问题咨询', description: '我的订单一直没有更新', category: 'order', priority: 'normal' } }
        end
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '401', '未登录或 Token 无效' do
        let(:Authorization) { 'Bearer invalid.token' }
        let(:body) { { ticket: { subject: '测试' } } }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end

        run_test!
      end

      response '422', '参数验证失败（如 subject 为空）' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 error: {
                   type: :object,
                   properties: {
                     code:    { type: :string, example: 'validation_error' },
                     message: { type: :string }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let(:body) { { ticket: { subject: '' } } }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end
  end

  # ── GET /api/v1/tickets/:id ──────────────────────────────────────────────

  path '/api/v1/tickets/{id}' do
    get '工单详情' do
      tags '工单'
      description '返回指定工单的详情，包含完整描述和公开消息列表。只能查看自己的工单。需要 Logto JWT 认证。'
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header, type: :string, required: true, description: 'Bearer <Logto JWT>'
      parameter name: :id, in: :path, type: :integer, required: true, description: '工单 ID'

      response '200', '获取成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:          { type: :integer },
                     ticket_no:   { type: :string },
                     subject:     { type: :string },
                     description: { type: :string, nullable: true },
                     status:      { type: :string },
                     category:    { type: :string },
                     priority:    { type: :string },
                     messages: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           id:          { type: :integer },
                           content:     { type: :string },
                           sender_type: { type: :string, description: 'User 或 AdminUser' },
                           internal:    { type: :boolean },
                           created_at:  { type: :string, format: 'date-time' }
                         }
                       }
                     },
                     created_at:  { type: :string, format: 'date-time' },
                     assigned_at: { type: :string, format: 'date-time', nullable: true },
                     resolved_at: { type: :string, format: 'date-time', nullable: true },
                     closed_at:   { type: :string, format: 'date-time', nullable: true }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:ticket) { create_my_ticket }
        let(:id) { ticket.id }
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

      response '404', '工单不存在或不属于当前用户' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:other_user2) { create(:user, email: 'other2-sw@example.com') }
        let!(:other_ticket) do
          t = create(:ticket)
          t.update_columns(creator_id: Ticket.id_to_uuid(other_user2.id), creator_type: 'User')
          t
        end
        let(:id) { other_ticket.id }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end
  end

  # ── POST /api/v1/tickets/:id/messages ────────────────────────────────────

  path '/api/v1/tickets/{id}/messages' do
    post '追加工单消息' do
      tags '工单'
      description <<~DESC
        用户向工单追加一条消息（回复客服）。
        - 工单必须处于非关闭状态（open / assigned / in_progress / resolved）
        - 只能向自己的工单追加消息
        需要 Logto JWT 认证。
      DESC
      security [Bearer: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization,
                in: :header, type: :string, required: true, description: 'Bearer <Logto JWT>'
      parameter name: :id, in: :path, type: :integer, required: true, description: '工单 ID'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          message: {
            type: :object,
            properties: {
              content: { type: :string, description: '消息内容（必填）' }
            },
            required: %w[content]
          }
        },
        required: %w[message]
      }

      response '201', '消息追加成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:          { type: :integer },
                     content:     { type: :string },
                     sender_type: { type: :string },
                     internal:    { type: :boolean },
                     created_at:  { type: :string, format: 'date-time' }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:ticket) { create_my_ticket(status: 'open') }
        let(:id) { ticket.id }
        let(:body) { { message: { content: '请问有更新吗？' } } }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '401', '未登录或 Token 无效' do
        let(:Authorization) { 'Bearer invalid.token' }
        let(:id) { 1 }
        let(:body) { { message: { content: '测试' } } }
        before do
          allow(Auth::JwtVerifier).to receive(:call)
            .and_raise(Auth::JwtVerifier::VerificationError, 'invalid')
        end

        run_test!
      end

      response '404', '工单不存在或不属于当前用户' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:other_user3) { create(:user, email: 'other3-sw@example.com') }
        let!(:other_ticket) do
          t = create(:ticket)
          t.update_columns(creator_id: Ticket.id_to_uuid(other_user3.id), creator_type: 'User')
          t
        end
        let(:id) { other_ticket.id }
        let(:body) { { message: { content: 'hack' } } }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '422', '工单已关闭或消息内容为空' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 error: {
                   type: :object,
                   properties: {
                     code:    { type: :string, example: 'ticket_closed' },
                     message: { type: :string }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:closed_ticket) { create_my_ticket(status: 'closed', closed_at: Time.current) }
        let(:id) { closed_ticket.id }
        let(:body) { { message: { content: '追加消息' } } }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end
  end

  # ── PATCH /api/v1/tickets/:id/close ──────────────────────────────────────

  path '/api/v1/tickets/{id}/close' do
    patch '关闭工单' do
      tags '工单'
      description <<~DESC
        用户主动关闭自己的工单。
        - 可关闭的状态：open / assigned / in_progress / resolved
        - 已关闭（closed）的工单无法再次关闭
        需要 Logto JWT 认证。
      DESC
      security [Bearer: []]
      produces 'application/json'

      parameter name: :Authorization,
                in: :header, type: :string, required: true, description: 'Bearer <Logto JWT>'
      parameter name: :id, in: :path, type: :integer, required: true, description: '工单 ID'

      response '200', '工单关闭成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:        { type: :integer },
                     ticket_no: { type: :string },
                     status:    { type: :string, enum: %w[closed] },
                     closed_at: { type: :string, format: 'date-time' }
                   }
                 }
               }

        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:ticket) { create_my_ticket(status: 'open') }
        let(:id) { ticket.id }
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

      response '404', '工单不存在或不属于当前用户' do
        let(:Authorization) { 'Bearer valid.logto.token' }
        let!(:other_user4) { create(:user, email: 'other4-sw@example.com') }
        let!(:other_ticket) do
          t = create(:ticket, status: 'open')
          t.update_columns(creator_id: Ticket.id_to_uuid(other_user4.id), creator_type: 'User')
          t
        end
        let(:id) { other_ticket.id }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end

      response '422', '工单状态不允许关闭（已关闭）' do
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
        let!(:closed_ticket) { create_my_ticket(status: 'closed', closed_at: Time.current) }
        let(:id) { closed_ticket.id }
        before { allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims) }

        run_test!
      end
    end
  end
end
