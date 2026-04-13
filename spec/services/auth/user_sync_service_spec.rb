# frozen_string_literal: true

require 'rails_helper'

# Auth::UserSyncService 单元测试
# Unit tests for Auth::UserSyncService
#
# 验证 Logto claims → 本地 User 的幂等同步行为
# Validates idempotent sync behavior from Logto claims → local User
#
RSpec.describe Auth::UserSyncService do
  # 伪造 TokenClaims（不需要真实 JWT）
  # Fake TokenClaims (no real JWT needed)
  def make_claims(sub:, email: nil, name: nil, phone_number: nil)
    Auth::TokenClaims.new(
      sub:          sub,
      email:        email,
      name:         name,
      phone_number: phone_number,
      raw:          {}
    )
  end

  # -----------------------------------------------------------------------
  # 创建新用户 / Create new user
  # -----------------------------------------------------------------------
  describe '.call — first-time login (user does not exist)' do
    let(:claims) do
      make_claims(
        sub:          'logto-abc-001',
        email:        'Alice@Example.com',
        name:         'Alice',
        phone_number: '+8613800138001'
      )
    end

    it 'creates a new User' do
      expect {
        described_class.call(claims)
      }.to change(User, :count).by(1)
    end

    it 'stores the correct external_id' do
      user = described_class.call(claims)
      expect(user.external_id).to eq('logto-abc-001')
    end

    it 'stores a downcased email' do
      user = described_class.call(claims)
      expect(user.email).to eq('alice@example.com')
    end

    it 'stores the name as nickname' do
      user = described_class.call(claims)
      expect(user.nickname).to eq('Alice')
    end

    it 'stores the phone number' do
      user = described_class.call(claims)
      expect(user.phone).to eq('+8613800138001')
    end

    it 'sets auth_provider to logto' do
      user = described_class.call(claims)
      expect(user.auth_provider).to eq('logto')
    end

    it 'does not set encrypted_password' do
      user = described_class.call(claims)
      expect(user.encrypted_password).to be_nil
    end
  end

  # -----------------------------------------------------------------------
  # 幂等性：同一 sub 重复调用 / Idempotency: same sub called again
  # -----------------------------------------------------------------------
  describe '.call — idempotency (same sub called twice)' do
    let!(:existing_user) do
      create(:user, external_id: 'logto-idem-001', email: 'bob@example.com')
    end

    let(:claims) { make_claims(sub: 'logto-idem-001', email: 'bob@example.com') }

    it 'does NOT create a second User' do
      expect {
        described_class.call(claims)
      }.not_to change(User, :count)
    end

    it 'returns the existing User' do
      user = described_class.call(claims)
      expect(user.id).to eq(existing_user.id)
    end
  end

  # -----------------------------------------------------------------------
  # 字段更新 / Field update on re-sync
  # -----------------------------------------------------------------------
  describe '.call — updates changed fields' do
    let!(:existing_user) do
      create(:user,
             external_id: 'logto-update-001',
             email:        'old@example.com',
             nickname:     'OldName',
             phone:        nil)
    end

    let(:claims) do
      make_claims(
        sub:          'logto-update-001',
        email:        'new@example.com',
        name:         'NewName',
        phone_number: '+8613900139001'
      )
    end

    it 'updates email' do
      user = described_class.call(claims)
      expect(user.reload.email).to eq('new@example.com')
    end

    it 'updates nickname' do
      user = described_class.call(claims)
      expect(user.reload.nickname).to eq('NewName')
    end

    it 'updates phone' do
      user = described_class.call(claims)
      expect(user.reload.phone).to eq('+8613900139001')
    end
  end

  # -----------------------------------------------------------------------
  # 无邮箱 claims（手机号注册用户）
  # Claims with no email (phone-only Logto user)
  # -----------------------------------------------------------------------
  describe '.call — no email in claims' do
    let(:claims) { make_claims(sub: 'logto-phone-001', phone_number: '+8613700137001') }

    it 'creates a User with an empty-string email (DB NOT NULL placeholder)' do
      user = described_class.call(claims)
      # DB constraint: email NOT NULL DEFAULT '' — phone-only users get ''
      expect(user.email).to eq('')
    end

    it 'stores the phone number' do
      user = described_class.call(claims)
      expect(user.phone).to eq('+8613700137001')
    end
  end

  # -----------------------------------------------------------------------
  # 非法 claims（sub 为空）
  # Invalid claims (blank sub)
  # -----------------------------------------------------------------------
  describe '.call with blank sub' do
    it 'raises SyncError' do
      claims = make_claims(sub: '')
      expect {
        described_class.call(claims)
      }.to raise_error(Auth::UserSyncService::SyncError, /blank/)
    end
  end
end
