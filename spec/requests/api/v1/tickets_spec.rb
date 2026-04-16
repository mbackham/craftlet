# frozen_string_literal: true

require 'rails_helper'

# spec/requests/api/v1/tickets_spec.rb
#
# 工单系统 API 测试
# GET    /api/v1/tickets
# POST   /api/v1/tickets
# GET    /api/v1/tickets/:id
# POST   /api/v1/tickets/:id/messages
# PATCH  /api/v1/tickets/:id/close
#
RSpec.describe 'Tickets API', type: :request do
  let(:logto_sub)   { 'logto-ticket-001' }
  let(:logto_email) { 'ticket-user@example.com' }
  let!(:user)       { create(:user, external_id: logto_sub, email: logto_email) }
  let!(:other_user) { create(:user, email: 'other-ticket@example.com') }

  let(:valid_claims) do
    Auth::TokenClaims.new(
      sub: logto_sub, email: logto_email,
      name: nil, phone_number: nil, raw: {}
    )
  end

  def auth_headers
    allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims)
    { 'Authorization' => 'Bearer valid.test.token' }
  end

  def create_my_ticket(attrs = {})
    ticket = create(:ticket, attrs)
    # Override creator_id to point to our user
    ticket.update_columns(
      creator_id:   Ticket.id_to_uuid(user.id),
      creator_type: 'User'
    )
    ticket
  end

  def create_other_ticket
    ticket = create(:ticket)
    ticket.update_columns(
      creator_id:   Ticket.id_to_uuid(other_user.id),
      creator_type: 'User'
    )
    ticket
  end

  # ── GET /api/v1/tickets ───────────────────────────────────────────────────

  describe 'GET /api/v1/tickets' do
    context 'without authentication' do
      it 'returns 401' do
        get '/api/v1/tickets'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      let!(:my_tickets)    { 2.times.map { create_my_ticket } }
      let!(:other_ticket)  { create_other_ticket }

      it 'returns only current user\'s tickets' do
        get '/api/v1/tickets', headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body['data'].length).to eq(2)
        expect(body['meta']['total_count']).to eq(2)
      end

      it 'does NOT return other user\'s tickets' do
        get '/api/v1/tickets', headers: auth_headers
        body = JSON.parse(response.body)
        ids = body['data'].map { |t| t['id'] }
        expect(ids).not_to include(other_ticket.id)
      end

      it 'includes required fields' do
        get '/api/v1/tickets', headers: auth_headers
        body = JSON.parse(response.body)
        ticket_data = body['data'].first
        expect(ticket_data).to include('ticket_no', 'subject', 'status', 'category', 'priority', 'created_at')
      end

      it 'orders by created_at desc' do
        get '/api/v1/tickets', headers: auth_headers
        body = JSON.parse(response.body)
        created_ats = body['data'].map { |t| t['created_at'] }
        expect(created_ats).to eq(created_ats.sort.reverse)
      end
    end
  end

  # ── GET /api/v1/tickets/:id ──────────────────────────────────────────────

  describe 'GET /api/v1/tickets/:id' do
    let!(:my_ticket)    { create_my_ticket }
    let!(:other_ticket) { create_other_ticket }

    context 'without authentication' do
      it 'returns 401' do
        get "/api/v1/tickets/#{my_ticket.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      it 'returns 200 for own ticket' do
        get "/api/v1/tickets/#{my_ticket.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'id')).to eq(my_ticket.id)
        expect(body.dig('data', 'ticket_no')).to eq(my_ticket.ticket_no)
      end

      it 'includes description and messages in detail view' do
        get "/api/v1/tickets/#{my_ticket.id}", headers: auth_headers
        body = JSON.parse(response.body)
        expect(body['data']).to include('description', 'messages')
      end

      it 'returns 404 for another user\'s ticket' do
        get "/api/v1/tickets/#{other_ticket.id}", headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end

      it 'returns 404 for non-existent ticket' do
        get '/api/v1/tickets/999999', headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ── POST /api/v1/tickets ─────────────────────────────────────────────────

  describe 'POST /api/v1/tickets' do
    let(:valid_params) do
      {
        ticket: {
          subject:     '我的订单出了问题',
          description: '订单号 ORD20260416 一直没收到货',
          category:    'order',
          priority:    'normal'
        }
      }
    end

    context 'without authentication' do
      it 'returns 401' do
        post '/api/v1/tickets', params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      it 'creates a ticket and returns 201' do
        expect {
          post '/api/v1/tickets', params: valid_params, headers: auth_headers
        }.to change(Ticket, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'status')).to eq('open')
        expect(body.dig('data', 'subject')).to eq('我的订单出了问题')
      end

      it 'assigns creator_id to current user' do
        post '/api/v1/tickets', params: valid_params, headers: auth_headers
        ticket = Ticket.last
        expect(ticket.creator_id).to eq(Ticket.id_to_uuid(user.id))
        expect(ticket.creator_type).to eq('User')
      end

      it 'generates a ticket_no' do
        post '/api/v1/tickets', params: valid_params, headers: auth_headers
        body = JSON.parse(response.body)
        expect(body.dig('data', 'ticket_no')).to be_present
        expect(body.dig('data', 'ticket_no')).to match(/\ATK-\d{8}-/)
      end

      it 'returns 422 when subject is blank' do
        post '/api/v1/tickets', params: { ticket: { subject: '' } }, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body['success']).to be false
      end

      it 'returns 422 for invalid category' do
        post '/api/v1/tickets',
             params: { ticket: { subject: '测试', category: 'invalid' } },
             headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'enqueues a TicketNotificationJob' do
        expect {
          post '/api/v1/tickets', params: valid_params, headers: auth_headers
        }.to have_enqueued_job(Notifications::TicketNotificationJob).with(
          hash_including(event: 'created')
        )
      end
    end
  end

  # ── POST /api/v1/tickets/:id/messages ────────────────────────────────────

  describe 'POST /api/v1/tickets/:id/messages' do
    let!(:open_ticket)   { create_my_ticket(status: 'open') }
    let!(:closed_ticket) { create_my_ticket(status: 'closed', closed_at: Time.current) }

    context 'without authentication' do
      it 'returns 401' do
        post "/api/v1/tickets/#{open_ticket.id}/messages",
             params: { message: { content: '请问有更新吗？' } }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      it 'adds a message to an open ticket' do
        expect {
          post "/api/v1/tickets/#{open_ticket.id}/messages",
               params: { message: { content: '请问有更新吗？' } },
               headers: auth_headers
        }.to change(TicketMessage, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'content')).to eq('请问有更新吗？')
      end

      it 'returns 422 when ticket is closed' do
        post "/api/v1/tickets/#{closed_ticket.id}/messages",
             params: { message: { content: '追加消息' } },
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body.dig('error', 'code')).to eq('ticket_closed')
      end

      it 'returns 404 for another user\'s ticket' do
        other_ticket = create_other_ticket
        post "/api/v1/tickets/#{other_ticket.id}/messages",
             params: { message: { content: 'hack' } },
             headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end

      it 'returns 422 when content is blank' do
        post "/api/v1/tickets/#{open_ticket.id}/messages",
             params: { message: { content: '' } },
             headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ── PATCH /api/v1/tickets/:id/close ──────────────────────────────────────

  describe 'PATCH /api/v1/tickets/:id/close' do
    let!(:open_ticket)     { create_my_ticket(status: 'open') }
    let!(:resolved_ticket) { create_my_ticket(status: 'resolved', resolved_at: Time.current) }
    let!(:closed_ticket)   { create_my_ticket(status: 'closed', closed_at: Time.current) }

    context 'without authentication' do
      it 'returns 401' do
        patch "/api/v1/tickets/#{open_ticket.id}/close"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      it 'closes an open ticket' do
        patch "/api/v1/tickets/#{open_ticket.id}/close", headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'status')).to eq('closed')
        expect(open_ticket.reload.status).to eq('closed')
      end

      it 'closes a resolved ticket' do
        patch "/api/v1/tickets/#{resolved_ticket.id}/close", headers: auth_headers
        expect(response).to have_http_status(:ok)
        expect(resolved_ticket.reload.status).to eq('closed')
      end

      it 'returns 422 for already closed ticket' do
        patch "/api/v1/tickets/#{closed_ticket.id}/close", headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body.dig('error', 'code')).to eq('invalid_state')
      end

      it 'returns 404 for another user\'s ticket' do
        other_ticket = create_other_ticket
        patch "/api/v1/tickets/#{other_ticket.id}/close", headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
