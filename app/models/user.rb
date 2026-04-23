class User < ApplicationRecord
  # ⚠️  devise-jwt 已移除（Week 0 改造）。User 认证由 Logto JWT 中间件负责（Week 1 实现）。
  # ⚠️  devise-jwt removed (Week 0 refactor). Authentication is handled by Logto JWT middleware (Week 1).
  #
  # 保留的 Devise 模块 / Retained Devise modules:
  #   :database_authenticatable — 保留密码字段结构，供 legacy 用户使用 / keeps password field structure for legacy users
  #   :recoverable             — 密码重置邮件（未来 Web 端可能用到）/ password reset mail
  #   :rememberable            — remember me cookie
  #   :lockable                — 账号锁定 / account lockout
  #   :trackable               — 登录记录 / sign-in tracking
  #
  # 已移除 / Removed:
  #   :registerable      — App 端通过 Logto 注册，无需 Devise 注册路由 / App registers via Logto
  #   :validatable       — Logto 用户没有密码，不能用 email+password 验证 / Logto users have no password
  #   :jwt_authenticatable — 核心改造点，替换为 ExternalJwtAuthenticatable / replaced by ExternalJwtAuthenticatable
  #
  devise :database_authenticatable, :recoverable,
         :rememberable, :lockable, :trackable

  has_many :roles, dependent: :destroy
  has_one :merchant_profile, dependent: :destroy
  has_many :device_tokens, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :bracelet_configs, dependent: :destroy

  # ⚠️  customer_orders / merchant_orders 不能用 has_many！
  #
  # 原因 / Reason:
  #   orders.customer_id 存储的是 UUID 格式（"00000000-0000-0000-0000-{12位bigint}"），
  #   而 User.id 是 bigint。Rails has_many 生成的 SQL 为：
  #     WHERE orders.customer_id = 42   ← bigint，永远匹配不到 UUID 字符串
  #   结果：始终返回空集合。
  #
  #   orders.customer_id stores a UUID-encoded bigint ("00000000-0000-0000-0000-{12-digit}").
  #   User.id is a bigint. Rails has_many generates:
  #     WHERE orders.customer_id = 42   ← bigint, never matches the UUID string
  #   Result: always returns an empty relation.
  #
  # 解决方案 / Solution:
  #   用实例方法手动注入 UUID 格式的 id 进行查询，与 UuidIdentity concern 保持一致。
  #   Use instance methods to inject the UUID-encoded id into the query,
  #   consistent with the UuidIdentity concern on the Order model.

  def customer_orders
    Order.where(customer_id: Order.id_to_uuid(id))
  end

  def merchant_orders
    Order.where(merchant_id: Order.id_to_uuid(id))
  end

  # Admin RBAC associations
  has_many :admin_user_roles, dependent: :destroy
  has_many :admin_roles, through: :admin_user_roles
  has_many :audit_logs, foreign_key: :actor_id, dependent: :nullify

  def has_role?(role_type)
    roles.where(role_type: role_type, is_active: true).exists?
  end

  def customer?
    has_role?("customer")
  end

  def merchant?
    has_role?("merchant")
  end

  # Admin RBAC methods
  def admin_has_role?(code)
    admin_roles.where(code: code).exists?
  end

  def admin_can?(permission_code)
    AdminPermission.joins(admin_roles: :admin_user_roles)
                   .where(admin_user_roles: { user_id: id })
                   .where(code: permission_code)
                   .exists?
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[email phone nickname created_at updated_at status]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[admin_roles business_roles]
  end
end
