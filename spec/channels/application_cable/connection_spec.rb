# frozen_string_literal: true

require 'rails_helper'

# spec/channels/application_cable/connection_spec.rb
#
# ApplicationCable::Connection — WebSocket 认证测试
#
# 验收标准：
#   ✅ 有效 JWT token → 连接成功，current_user 正确赋值
#   ✅ token 缺失 → 连接被拒
#   ✅ 无效/过期 JWT → 连接被拒
#   ✅ JWKS 网络故障 → 连接被拒（不是 500）
#
RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:logto_sub)  { 'ws-test-logto-sub-001' }
  let!(:user)      { create(:user, external_id: logto_sub, email: 'ws-user@example.com') }

  let(:valid_claims) do
    Auth::TokenClaims.new(
      sub: logto_sub, email: user.email,
      name: nil, phone_number: nil, raw: {}
    )
  end

  # ── 有效 Token 连接成功 ───────────────────────────────────────────────────

  describe '有效 JWT token（URL query string）' do
    before do
      allow(Auth::JwtVerifier).to receive(:call).with('valid.ws.token').and_return(valid_claims)
      allow(Auth::UserSyncService).to receive(:call).with(valid_claims).and_return(user)
    end

    it 'connects successfully and assigns current_user' do
      connect '/cable', params: { token: 'valid.ws.token' }

      expect(connection.current_user).to eq(user)
    end
  end

  # ── 有效 Token（Authorization 请求头）────────────────────────────────────

  describe '有效 JWT token（Authorization header）' do
    before do
      allow(Auth::JwtVerifier).to receive(:call).with('header.ws.token').and_return(valid_claims)
      allow(Auth::UserSyncService).to receive(:call).with(valid_claims).and_return(user)
    end

    it 'connects successfully via Authorization header' do
      connect '/cable', headers: { 'Authorization' => 'Bearer header.ws.token' }

      expect(connection.current_user).to eq(user)
    end
  end

  # ── Token 缺失 ────────────────────────────────────────────────────────────

  describe 'token 缺失时' do
    it 'rejects connection with no token (P0 Fix: must not continue execution)' do
      expect {
        connect '/cable'
      }.to have_rejected_connection
    end

    it 'rejects connection when token is blank string' do
      expect {
        connect '/cable', params: { token: '' }
      }.to have_rejected_connection
    end
  end

  # ── 无效 JWT ─────────────────────────────────────────────────────────────

  describe '无效/过期 JWT token' do
    before do
      allow(Auth::JwtVerifier).to receive(:call)
        .and_raise(Auth::JwtVerifier::VerificationError, 'Signature verification failed')
    end

    it 'rejects connection on verification error' do
      expect {
        connect '/cable', params: { token: 'invalid.token.here' }
      }.to have_rejected_connection
    end
  end

  # ── JWKS 网络故障 ─────────────────────────────────────────────────────────

  describe 'JWKS 网络故障时（P0 Fix: 应拒绝而非 500）' do
    before do
      allow(Auth::JwtVerifier).to receive(:call)
        .and_raise(Auth::JwksFetcher::FetchError, 'Connection refused')
    end

    it 'rejects connection gracefully instead of raising 500' do
      expect {
        connect '/cable', params: { token: 'any.token.here' }
      }.to have_rejected_connection
    end
  end

  # ── UserSync 返回 nil ─────────────────────────────────────────────────────

  describe '用户同步失败（UserSyncService 返回 nil）' do
    before do
      allow(Auth::JwtVerifier).to receive(:call).and_return(valid_claims)
      allow(Auth::UserSyncService).to receive(:call).and_return(nil)
    end

    it 'rejects connection when user sync fails' do
      expect {
        connect '/cable', params: { token: 'valid.token.but.no.user' }
      }.to have_rejected_connection
    end
  end
end
