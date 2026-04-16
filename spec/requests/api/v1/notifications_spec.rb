# frozen_string_literal: true

require 'rails_helper'

# spec/requests/api/v1/notifications_spec.rb
#
# 通知列表 API 测试
# GET   /api/v1/notifications           → 通知列表（分页）
# PATCH /api/v1/notifications/mark_read → 批量标记已读
#
RSpec.describe 'Notifications API', type: :request do
  let(:logto_sub)   { 'logto-notif-user-001' }
  let(:logto_email) { 'notif@example.com' }
  let!(:user)       { create(:user, external_id: logto_sub, email: logto_email) }
  let!(:other_user) { create(:user, email: 'other-notif@example.com') }

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

  def create_notification(attrs = {})
    Notification.create!({
      user: user,
      title: '测试通知',
      body: '这是一条测试通知内容',
      notification_type: 'order_accepted'
    }.merge(attrs))
  end

  # ── GET /api/v1/notifications ────────────────────────────────────────────

  describe 'GET /api/v1/notifications' do
    context 'without authentication' do
      it 'returns 401' do
        get '/api/v1/notifications'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      let!(:unread_notifications) { 3.times.map { create_notification } }
      let!(:read_notifications) do
        2.times.map { create_notification(read_at: 1.hour.ago) }
      end
      let!(:other_notification) do
        Notification.create!(
          user: other_user,
          title: '别人的通知',
          body: '不应该出现',
          notification_type: 'system'
        )
      end

      it 'returns only current user\'s notifications with pagination' do
        get '/api/v1/notifications', headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body['data'].length).to eq(5)
        expect(body['meta']['total_count']).to eq(5)
        expect(body['meta']).to include('current_page', 'total_pages', 'per_page')
      end

      it 'returns notifications sorted by created_at desc' do
        get '/api/v1/notifications', headers: auth_headers
        body = JSON.parse(response.body)
        ids = body['data'].map { |n| n['id'] }
        all_ids = (unread_notifications + read_notifications).map(&:id).sort.reverse
        expect(ids).to eq(all_ids)
      end

      it 'includes read status in response' do
        get '/api/v1/notifications', headers: auth_headers
        body = JSON.parse(response.body)
        read_items   = body['data'].select { |n| n['read'] == true }
        unread_items = body['data'].select { |n| n['read'] == false }
        expect(read_items.length).to eq(2)
        expect(unread_items.length).to eq(3)
      end
    end
  end

  # ── PATCH /api/v1/notifications/mark_read ────────────────────────────────

  describe 'PATCH /api/v1/notifications/mark_read' do
    context 'without authentication' do
      it 'returns 401' do
        patch '/api/v1/notifications/mark_read'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid JWT' do
      let!(:notif1) { create_notification }
      let!(:notif2) { create_notification }
      let!(:notif3) { create_notification }
      let!(:already_read) { create_notification(read_at: 1.day.ago) }

      it 'marks specific notifications as read by ids' do
        patch '/api/v1/notifications/mark_read',
              params: { ids: [notif1.id, notif2.id] },
              headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to be true
        expect(body.dig('data', 'marked_count')).to eq(2)

        expect(notif1.reload.read?).to be true
        expect(notif2.reload.read?).to be true
        expect(notif3.reload.read?).to be false
      end

      it 'marks ALL unread notifications when no ids provided' do
        patch '/api/v1/notifications/mark_read', headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        # 3 条未读 (notif1/2/3)，already_read 已读跳过
        expect(body.dig('data', 'marked_count')).to eq(3)

        expect(notif1.reload.read?).to be true
        expect(notif2.reload.read?).to be true
        expect(notif3.reload.read?).to be true
      end

      it 'does not mark other users\' notifications' do
        other_notif = Notification.create!(
          user: other_user,
          title: '别人',
          body: 'body',
          notification_type: 'system'
        )

        patch '/api/v1/notifications/mark_read',
              params: { ids: [other_notif.id] },
              headers: auth_headers

        expect(other_notif.reload.read?).to be false
      end
    end
  end
end
