# frozen_string_literal: true

module Auth
  # UserSyncService — 幂等地同步 Logto 用户到本地 User 记录
  # UserSyncService — Idempotently syncs a Logto user to a local User record
  #
  # 策略 / Strategy:
  #   1. 按 external_id（Logto sub）查找 User
  #   2. 找到 → 更新 email / name / phone_number 等可变字段
  #   3. 未找到 → 创建新 User（无密码，auth_provider: 'logto'）
  #
  #   1. Find User by external_id (Logto sub)
  #   2. Found → update mutable fields (email, name, phone_number)
  #   3. Not found → create new User (no password, auth_provider: 'logto')
  #
  # 线程安全 / Thread safety:
  #   使用 find_or_create_by + retry on unique constraint 避免竞态条件。
  #   Uses find_or_create_by + retry on unique constraint to avoid race conditions.
  #
  # 用法 / Usage:
  #   user = Auth::UserSyncService.call(claims)   # claims: Auth::TokenClaims
  #
  class UserSyncService
    class SyncError < StandardError; end

    MAX_RETRIES = 2

    def self.call(claims)
      new(claims).call
    end

    def initialize(claims)
      @claims = claims
    end

    def call
      raise SyncError, 'TokenClaims sub is blank' if @claims.sub.blank?

      retries = 0
      begin
        sync_user
      rescue ActiveRecord::RecordNotUnique
        # 极罕见的并发竞态：两个请求同时为同一 sub 创建 User
        # Very rare race: two concurrent requests creating User for the same sub
        retry if (retries += 1) <= MAX_RETRIES
        User.find_by!(external_id: @claims.sub)
      end
    end

    private

    def sync_user
      user = User.find_by(external_id: @claims.sub)

      if user
        update_if_changed(user)
      else
        create_user
      end
    end

    def create_user
      User.create!(
        external_id:        @claims.sub,
        auth_provider:      'logto',
        # DB 约束 email NOT NULL DEFAULT '' — 手机号用户使用空字符串占位
        # DB constraint email NOT NULL DEFAULT '' — phone-only users get empty string placeholder
        email:              normalize_email || '',
        phone:              @claims.phone_number.presence,
        nickname:           @claims.name.presence,
        # Devise database_authenticatable 字段 — Logto 用户无密码
        # Devise database_authenticatable fields — Logto users have no password
        encrypted_password: nil,
        # Devise lockable / trackable
        failed_attempts:    0
      )
    end

    def update_if_changed(user)
      attrs = {}
      attrs[:email]    = normalize_email                 if normalize_email.present? && user.email != normalize_email
      attrs[:phone]    = @claims.phone_number.presence   if @claims.phone_number.present? && user.phone != @claims.phone_number
      attrs[:nickname] = @claims.name.presence           if @claims.name.present? && user.nickname != @claims.name

      user.update!(attrs) if attrs.any?
      user
    end

    def normalize_email
      @normalize_email ||= @claims.email.to_s.downcase.presence
    end
  end
end
