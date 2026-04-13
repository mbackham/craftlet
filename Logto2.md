# Craftlet 后端开发计划 v2.1（终版）

> 基于 `评估.md` 风险分析修正 + 代码库深度审计结果
> 更新时间：2026-04-13
> 总工期：**30 个工作日（约 6 周）**

---

## 📋 修正说明（相比 v1.0 的变化）

| 变更项 | v1.0 | v2.1 | 原因 |
|--------|------|------|------|
| 新增 Week 0 | ❌ | ✅ 2天 | 修复阻塞性数据层问题 |
| UUID 修复策略 | - | 方案 E（规范化封装） | schema 中 17 个 UUID 列，改列类型风险过大 |
| Day 4 认证移除 | 1天 | 2天 | Devise 耦合复杂 + 6 个已有 Controller 需迁移 |
| Stripe 集成 | Day 18（1天） | ❌ 移至 v2 | 1天不现实，不阻塞 MVP |
| 工单系统 | Day 17（2天） | Day 16（1天） | 模型已存在，只需写 API 层 |
| 联调周期 | 5天 | 7天 | 全链路复杂度高，需要 buffer |
| **总工期** | 25天 | **30天** | |

---

## 🗺️ 总体路线图

```
Week 0 │ 数据层修复 + Devise 审计（阻塞性前置）
Week 1 │ 认证层改造（LogTo JWT 中间件）
Week 2 │ 用户端核心 API（订单 + 支付）
Week 3 │ 商家端核心 API（入驻 + 接单 + 结算）
Week 4 │ 扩展功能（推送 + 工单 + ActionCable + i18n）
Week 5-6 │ 联调 + 性能优化 + 部署上线
```

---

## ⚠️ 先决条件 Checklist（开始前必须确认）

- [ ] Logto Cloud 免费版注册完成（开发阶段用 Cloud，上线前迁自部署）
- [ ] 微信开放平台：App ID、App Secret、OAuth 回调域名已申请
- [ ] Apple Developer Account：Sign in with Apple 已配置
- [ ] 确认 Stripe 推至 v2（不进入本期排期）
- [ ] 确认是否先做 MVP 单端（影响 Week 2-3 并行度）

---

## WEEK 0：数据层修复 + 前置审计（2天）

> 🎯 目标：消除所有阻塞性问题，为 Week 1 认证改造扫清障碍
> ⚠️ 这 2 天必须完成，否则后续所有 API 开发都会遇到数据关联问题

---

### Day 0a（周一）— UUID/bigint 关联规范化

**问题根因：**
```ruby
# 当前 hack 代码（order.rb、bid.rb、ticket.rb 等均存在）
def customer_user
  User.find_by(id: customer_id.to_s.split('-').last.to_i)
end
```

**影响面（代码库审计结果）：** schema 中共有 **17 个 UUID 列**引用了 User/AdminUser 的 bigint ID：

| 表 | UUID 列 | 引用目标 |
|----|---------|----------|
| orders | `customer_id`, `merchant_id`, `canceled_by_id` | User |
| bids | `bidder_id` | User |
| tickets | `creator_id`, `assignee_id` | User/AdminUser |
| ticket_messages | `sender_id` | User/AdminUser |
| audit_logs | `actor_id`, `subject_id` | User / 多态 |
| merchant_profiles | `approved_by_admin_id`, `rejected_by_admin_id` | AdminUser |
| merchant_review_logs | `operator_admin_id` | AdminUser |
| risk_events | `subject_id`, `resolved_by_id` | 多态 / AdminUser |
| reconciliation_batches | `requested_by_id` | AdminUser |
| outbox_events | `aggregate_id` | 多态 |

> ⚠️ 改列类型（方案 A）只能修复 2 列，却有 17 列需要处理，且生产环境有存量数据无法安全 `change_column`。

**采用方案 E（规范化封装）— 零 migration、零风险：**

```ruby
# app/models/concerns/uuid_identity.rb
# 统一 UUID <-> bigint 转换逻辑，消除所有散落的 hack 代码
module UuidIdentity
  extend ActiveSupport::Concern

  class_methods do
    # 将 bigint User/AdminUser ID 转为 UUID 格式（数据库存储格式）
    # 格式：00000000-0000-0000-0000-000000000042
    def id_to_uuid(numeric_id)
      return nil if numeric_id.blank?
      sprintf('00000000-0000-0000-0000-%012d', numeric_id.to_i)
    end

    # 将 UUID 转为 bigint ID（查询时）
    def uuid_to_id(uuid)
      return nil if uuid.blank?
      uuid.to_s.split('-').last.to_i
    end

    # 从 UUID 列查找 User
    def find_user_by_uuid(uuid_value)
      return nil if uuid_value.blank?
      User.find_by(id: uuid_to_id(uuid_value))
    end

    # 从 UUID 列查找 AdminUser
    def find_admin_by_uuid(uuid_value)
      return nil if uuid_value.blank?
      AdminUser.find_by(id: uuid_to_id(uuid_value))
    end
  end
end
```

**重构所有模型（统一替换 hack 代码）：**

```ruby
# app/models/order.rb — 替换 hack
class Order < ApplicationRecord
  include UuidIdentity

  def customer
    @customer ||= self.class.find_user_by_uuid(customer_id)
  end

  def merchant
    @merchant ||= self.class.find_user_by_uuid(merchant_id)
  end

  def customer=(user)
    self.customer_id = self.class.id_to_uuid(user&.id)
    @customer = user
  end

  def merchant=(user)
    self.merchant_id = self.class.id_to_uuid(user&.id)
    @merchant = user
  end

  # 删除旧的 customer_user / merchant_user hack 方法
end

# app/models/bid.rb — 替换 hack
class Bid < ApplicationRecord
  include UuidIdentity

  def bidder
    @bidder ||= self.class.find_user_by_uuid(bidder_id)
  end

  def bidder=(user)
    self.bidder_id = self.class.id_to_uuid(user&.id)
    @bidder = user
  end

  # 删除旧的 bidder hack 方法
end

# app/models/ticket.rb — 替换 hack
class Ticket < ApplicationRecord
  include UuidIdentity

  def creator
    return nil if creator_id.blank?
    if creator_type == 'AdminUser'
      self.class.find_admin_by_uuid(creator_id)
    else
      self.class.find_user_by_uuid(creator_id)
    end
  end

  def assignee
    @assignee ||= self.class.find_admin_by_uuid(assignee_id)
  end

  # 删除旧的 creator / assignee hack 方法
end

# merchant_profile.rb 同理 — approved_by_admin / rejected_by_admin 已使用类似模式，
# 将 hack 替换为 self.class.find_admin_by_uuid 即可
```

**验收标准：**
- [ ] `Order.first.customer` 能正确返回 User 对象
- [ ] `Order.first.merchant` 能正确返回 User 对象
- [ ] `Bid.first.bidder` 能正确返回 User 对象
- [ ] `Ticket.first.creator` 能正确返回 User/AdminUser 对象
- [ ] 全局搜索 `split('-').last.to_i` 返回 0 结果（hack 代码已全部清除）
- [ ] 所有 hack 逻辑统一收敛到 `UuidIdentity` concern

---

### Day 0b（周二）— User 模型 Devise 审计 + NOT NULL 修复

**问题 1：encrypted_password NOT NULL**

```bash
# 生成 migration
rails g migration RelaxUserDeviseConstraints
```

```ruby
class RelaxUserDeviseConstraints < ActiveRecord::Migration[7.1]
  def change
    # 允许 Logto 创建的用户没有密码
    change_column_null :users, :encrypted_password, true
    change_column_default :users, :encrypted_password, nil

    # jti 字段：移除 NOT NULL（devise-jwt 移除后不再需要）
    change_column_null :users, :jti, true

    # 新增 Logto 相关字段
    add_column :users, :external_id, :string, comment: 'Logto sub claim'
    add_column :users, :auth_provider, :string, default: 'logto', comment: 'logto | devise(legacy)'
    add_column :users, :locale, :string, default: 'zh-CN'
    add_column :users, :country_code, :string, comment: 'CN / INTL'

    add_index :users, :external_id, unique: true
  end
end
```

**问题 2：Devise 模块影响面审计**

```
需要保留的 Devise 模块（AdminUser 和 Web 端依赖）：
✅ :database_authenticatable  → AdminUser session 登录需要
✅ :recoverable               → 密码重置邮件（Web 端）
✅ :rememberable              → Web 端 remember me
✅ :trackable                 → 登录记录
✅ :lockable                  → 账号锁定

需要从 User 移除的模块：
❌ :jwt_authenticatable       → 替换为 Logto JWT 验证
❌ :validatable               → 它要求 email+password 必填，Logto 用户没有密码

需要保留的 devise_for 路由：
✅ devise_for :admin_users    → ActiveAdmin 登录，完全保留
⚠️ devise_for :users         → 评估是否还有 Web 端使用，若无则移除
```

**编写回归测试基准（重要！）：**

```bash
# 为现有认证逻辑写测试，作为改造后的回归基准
# spec/requests/authentication_spec.rb
# spec/models/user_spec.rb
```

**验收标准：**
- [ ] Migration 执行成功，users 表结构正确
- [ ] AdminUser 登录 ActiveAdmin 正常
- [ ] 现有 API 测试全部通过（作为 Week 1 改造的回归基准）
- [ ] 影响面文档已整理（哪些 controller 用了 `authenticate_user!`）

---

## WEEK 1：认证层改造（6天）

> 🎯 目标：完成 Logto JWT 验证中间件，替换 devise-jwt，实现用户同步
> 前端可以用 Mock Token 并行开发，不需要等待本周完成

---

### Day 1（周一）— Logto 基础配置 + JWT 验证核心

**环境变量配置：**

```bash
# .env / credentials
LOGTO_ENDPOINT=https://your-tenant.logto.app
LOGTO_API_RESOURCE=https://api.craftlet.com
LOGTO_JWKS_URI=https://your-tenant.logto.app/oidc/jwks
```

**新建文件结构：**

```
config/initializers/logto_auth.rb
app/services/auth/
├── jwks_fetcher.rb        # JWKS 公钥获取 + 缓存
├── jwt_verifier.rb        # Token 签名验证
└── token_claims.rb        # Claims 结构体
app/controllers/concerns/
└── external_jwt_authenticatable.rb
```

**JWKS 缓存实现：**

```ruby
# app/services/auth/jwks_fetcher.rb
module Auth
  class JwksFetcher
    CACHE_KEY = 'logto:jwks'
    CACHE_TTL = 1.hour

    def self.fetch
      Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
        uri = URI(ENV['LOGTO_JWKS_URI'])
        response = Net::HTTP.get_response(uri)
        JSON.parse(response.body)
      end
    end

    def self.invalidate!
      Rails.cache.delete(CACHE_KEY)
    end
  end
end
```

**JWT 验证实现：**

```ruby
# app/services/auth/jwt_verifier.rb
module Auth
  class JwtVerifier
    class VerificationError < StandardError; end

    REQUIRED_CLAIMS = %w[sub iss aud exp].freeze

    def self.verify!(token)
      jwks = Auth::JwksFetcher.fetch
      jwks_hash = JWT::JWK::Set.new(jwks)

      payload, _header = JWT.decode(
        token,
        nil,
        true,
        algorithms: ['RS256'],
        jwks: jwks_hash,
        iss: "#{ENV['LOGTO_ENDPOINT']}/oidc",
        verify_iss: true,
        aud: ENV['LOGTO_API_RESOURCE'],
        verify_aud: true
      )

      payload
    rescue JWT::DecodeError, JWT::ExpiredSignature => e
      raise VerificationError, e.message
    end
  end
end
```

**验收标准：**
- [ ] `Auth::JwtVerifier.verify!(valid_token)` 返回正确 payload
- [ ] 过期 token 抛出 VerificationError
- [ ] JWKS 缓存 1 小时，Redis 中可见

---

### Day 2（周二）— ExternalJwtAuthenticatable Concern

```ruby
# app/controllers/concerns/external_jwt_authenticatable.rb
module ExternalJwtAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_from_logto!
  end

  private

  def authenticate_from_logto!
    token = extract_bearer_token
    return render_unauthorized('Missing token') if token.blank?

    begin
      @token_payload = Auth::JwtVerifier.verify!(token)
      @current_user = find_or_sync_user(@token_payload)
    rescue Auth::JwtVerifier::VerificationError => e
      render_unauthorized(e.message)
    end
  end

  def current_user
    @current_user
  end

  def extract_bearer_token
    request.headers['Authorization']&.delete_prefix('Bearer ')&.strip
  end

  def find_or_sync_user(payload)
    Auth::UserSyncService.call(payload)
  end

  def render_unauthorized(message = 'Unauthorized')
    render json: { error: message }, status: :unauthorized
  end
end
```

**ApplicationController 集成：**

```ruby
# app/controllers/api/v1/base_controller.rb（新建）
module Api
  module V1
    class BaseController < ActionController::API
      include ExternalJwtAuthenticatable

      rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

      private

      def render_forbidden
        render json: { error: 'Forbidden' }, status: :forbidden
      end
    end
  end
end
```

**验收标准：**
- [ ] 有效 token 的请求正常通过
- [ ] 无 token 返回 401
- [ ] 无效/过期 token 返回 401，错误信息清晰

---

### Day 3（周三）— 用户同步 Service + Webhook

**UserSyncService：**

```ruby
# app/services/auth/user_sync_service.rb
module Auth
  class UserSyncService
    def self.call(payload)
      new(payload).call
    end

    def initialize(payload)
      @sub = payload['sub']           # Logto user ID
      @email = payload['email']
      @name = payload['name']
      @locale = payload['locale'] || 'zh-CN'
      @payload = payload
    end

    def call
      user = User.find_by(external_id: @sub)

      if user
        sync_user_attributes(user)
      else
        create_user_from_logto
      end
    end

    private

    def create_user_from_logto
      User.create!(
        external_id: @sub,
        email: @email || generate_placeholder_email,
        encrypted_password: nil,        # Logto 用户无密码
        auth_provider: 'logto',
        locale: @locale,
        country_code: detect_country_code
      )
    end

    def sync_user_attributes(user)
      user.update_columns(
        email: @email || user.email,
        locale: @locale
      ) if user_attributes_changed?(user)
      user
    end

    def user_attributes_changed?(user)
      user.email != @email || user.locale != @locale
    end

    def generate_placeholder_email
      "logto_#{@sub}@placeholder.craftlet.com"
    end

    def detect_country_code
      # 根据 locale 或 IP 推断，后续可完善
      @locale&.start_with?('zh') ? 'CN' : 'INTL'
    end
  end
end
```

**Logto Webhook 处理：**

```ruby
# app/controllers/api/webhooks/logto_controller.rb
module Api
  module Webhooks
    class LogtoController < ActionController::API
      before_action :verify_webhook_signature

      def create
        event = params[:event]
        data = params[:data]

        case event
        when 'User.Created'
          # 用户在 Logto 侧创建，本地已通过 UserSyncService 处理，此处可记录日志
          Rails.logger.info("[Logto Webhook] User.Created: #{data[:id]}")
        when 'User.Deleted'
          user = User.find_by(external_id: data[:id])
          user&.update!(status: 'disabled', disabled_at: Time.current, disabled_reason: 'logto_deleted')
        when 'User.Data.Updated'
          user = User.find_by(external_id: data[:id])
          user&.update(email: data.dig(:primaryEmail))
        end

        head :ok
      end

      private

      def verify_webhook_signature
        signature = request.headers['logto-signature-sha-256']
        # 验证 HMAC-SHA256 签名
        expected = OpenSSL::HMAC.hexdigest(
          'SHA256',
          ENV['LOGTO_WEBHOOK_SECRET'],
          request.raw_post
        )
        head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(signature.to_s, expected)
      end
    end
  end
end
```

**验收标准：**
- [ ] 新 Logto 用户首次请求 API 时自动创建本地 User
- [ ] 重复请求不重复创建（幂等）
- [ ] Webhook 签名验证通过

---

### Day 4a（周四）— 移除 devise-jwt，保留 Devise 核心 + 迁移已有 Controller

**修改 User 模型：**

```ruby
# app/models/user.rb
# 修改前：
devise :database_authenticatable, :registerable, :recoverable,
       :rememberable, :validatable, :lockable, :trackable,
       :jwt_authenticatable, jwt_revocation_strategy: self

# 修改后：
devise :database_authenticatable, :recoverable,
       :rememberable, :lockable, :trackable
# 移除：:registerable（App 端通过 Logto 注册）
# 移除：:validatable（Logto 用户无密码，无法通过 email+password 验证）
# 移除：:jwt_authenticatable（核心改造点）
```

**移除 JTIMatcher：**

```ruby
# app/models/user.rb
# 删除：
include Devise::JWT::RevocationStrategies::JTIMatcher
```

**清理 devise 配置：**

```ruby
# config/initializers/devise.rb
# 删除 jwt 配置块（约 L271-L280）：
# config.jwt do |jwt|
#   jwt.secret = ENV['DEVISE_JWT_SECRET_KEY']
#   ...
# end
```

**清理路由（谨慎操作）：**

```ruby
# config/routes.rb
# 保留（AdminUser 需要）：
devise_for :admin_users, ActiveAdmin::Devise.config

# 评估后移除（App 端不再使用 Devise 登录）：
# devise_for :users  ← 如果 Web 端不再使用则移除
# 如果 Web 端仍需要，保留但限制 scope：
devise_for :users, only: [:passwords]  # 只保留密码重置
```

**Gemfile 清理：**

```ruby
# Gemfile
# 移除：
gem 'devise-jwt'  # ← 删除此行

# 保留：
gem 'devise'      # ← 保留，AdminUser 还需要
```

**⚠️ 迁移已有 6 个 Controller 的认证方式（关键步骤，不可遗漏）：**

当前以下 6 个 Controller 使用了 Devise 的 `authenticate_user!`，需要全部迁移：

```ruby
# 需要迁移的 Controller 清单：
app/controllers/api/v1/feedbacks_controller.rb     # authenticate_user!
app/controllers/api/v1/merchants_controller.rb     # authenticate_user!
app/controllers/api/v1/coupons_controller.rb       # authenticate_user!
app/controllers/api/v1/announcements_controller.rb # authenticate_user!
app/controllers/api/v1/faqs_controller.rb          # authenticate_user!
app/controllers/api/v1/banners_controller.rb       # authenticate_user!
```

迁移方式：这些 Controller 已继承 `Api::V1::BaseController`，
而 BaseController 已 include `ExternalJwtAuthenticatable`（Day 2 已完成），
所以需要做以下操作：

```ruby
# 1. 删除各 Controller 中显式调用的 before_action :authenticate_user!
#    （因为 BaseController 已有 before_action :authenticate_from_logto!）

# 2. 对于公开接口（banners/announcements/faqs），需要跳过认证：
class Api::V1::BannersController < BaseController
  skip_before_action :authenticate_from_logto!  # 公开接口，无需登录
end

class Api::V1::AnnouncementsController < BaseController
  skip_before_action :authenticate_from_logto!  # 公开接口，无需登录
end

class Api::V1::FaqsController < BaseController
  skip_before_action :authenticate_from_logto!  # 公开接口，无需登录
end

# 3. 对于需要登录的接口（feedbacks/coupons/merchants），
#    删除 authenticate_user! 即可，BaseController 的 authenticate_from_logto! 会自动生效
```

**验收标准：**
- [ ] `bundle install` 无报错
- [ ] `rails routes` 无异常
- [ ] AdminUser 相关路由完整保留
- [ ] 全局搜索 `authenticate_user!` 返回 0 结果（API Controller 中）
- [ ] 公开接口（banners/announcements/faqs）无需 token 即可访问
- [ ] 需登录接口（feedbacks/coupons/merchants）使用 Logto JWT 认证

---

### Day 4b（周五）— 全量回归测试 + AdminUser 验证

**执行回归测试：**

```bash
# 运行全部测试
bundle exec rspec

# 重点检查：
bundle exec rspec spec/models/user_spec.rb
bundle exec rspec spec/requests/
bundle exec rspec spec/models/admin_user_spec.rb
```

**手动验证 ActiveAdmin：**

```bash
# 启动服务器，手动测试：
# 1. /admin 登录页面正常显示
# 2. AdminUser 能正常登录
# 3. 各 Admin 资源页面正常加载
# 4. User 列表页面正常（无 Devise 相关报错）
```

**新认证流程集成测试：**

```ruby
# spec/requests/auth_flow_spec.rb
RSpec.describe 'Logto Authentication Flow' do
  describe 'with valid Logto token' do
    it 'creates user on first request' do
      # Mock JWT verify
      # 验证 User 被创建
    end

    it 'returns 200 for protected endpoint' do
      # 验证正常访问
    end
  end

  describe 'with invalid token' do
    it 'returns 401' do
      get '/api/v1/users/profile', headers: { 'Authorization' => 'Bearer invalid' }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
```

**验收标准：**
- [ ] 全部 RSpec 测试通过（或已知失败项有记录）
- [ ] ActiveAdmin 登录功能正常
- [ ] Logto JWT 认证端到端测试通过
- [ ] 无遗留的 devise-jwt 代码引用

---

### Day 5（下周一）— Serializer 基础建设 + 统一响应格式

**安装 blueprinter（推荐，轻量）：**

```ruby
# Gemfile
gem 'blueprinter'
gem 'pagy'  # 已有，确认版本
```

**基础 Serializer：**

```ruby
# app/blueprints/base_blueprint.rb
class BaseBlueprint < Blueprinter::Base
  # 统一时间格式
  field :created_at do |obj|
    obj.created_at&.iso8601
  end
end

# app/blueprints/user_blueprint.rb
class UserBlueprint < BaseBlueprint
  identifier :id

  fields :email, :locale, :country_code, :auth_provider

  view :with_roles do
    association :roles, blueprint: RoleBlueprint
  end

  view :profile do
    fields :phone_number, :avatar_url
    field :is_merchant do |user|
      user.merchant?
    end
  end
end
```

**统一响应格式（ApiResponse concern）：**

```ruby
# app/controllers/concerns/api_response.rb
module ApiResponse
  extend ActiveSupport::Concern

  def render_success(data:, status: :ok, meta: nil)
    response_body = { data: data }
    response_body[:meta] = meta if meta
    render json: response_body, status: status
  end

  def render_error(message:, status: :unprocessable_entity, errors: nil)
    response_body = { error: message }
    response_body[:errors] = errors if errors
    render json: response_body, status: status
  end

  def render_paginated(collection, blueprint:, blueprint_options: {})
    pagy, records = pagy(collection)
    render_success(
      data: blueprint.render_as_hash(records, **blueprint_options),
      meta: {
        current_page: pagy.page,
        total_pages: pagy.pages,
        total_count: pagy.count,
        per_page: pagy.items
      }
    )
  end
end
```

**验收标准：**
- [ ] `UserBlueprint.render(user)` 输出正确 JSON
- [ ] 分页响应包含 meta 信息
- [ ] 所有 API 响应格式统一

---

## WEEK 2：用户端核心 API（5天）

> 🎯 目标：完成消费者端所有核心 API，支撑 App 用户端功能

---

### Day 6（周二）— 用户资料 API

**新建 Controller：**

```ruby
# app/controllers/api/v1/users/profiles_controller.rb
module Api
  module V1
    module Users
      class ProfilesController < BaseController
        def show
          render_success(data: UserBlueprint.render_as_hash(current_user, view: :profile))
        end

        def update
          if current_user.update(profile_params)
            render_success(data: UserBlueprint.render_as_hash(current_user, view: :profile))
          else
            render_error(message: '更新失败', errors: current_user.errors.full_messages)
          end
        end

        private

        def profile_params
          params.require(:user).permit(:locale, :country_code, :phone_number, :avatar_url)
        end
      end
    end
  end
end
```

**路由：**

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    namespace :users do
      resource :profile, only: [:show, :update]
      resources :device_tokens, only: [:create, :destroy]
    end
  end
end
```

**DeviceToken 模型（新建）：**

```bash
rails g model DeviceToken user:references token:string platform:string
# platform: ios / android
```

**验收标准：**
- [ ] GET /api/v1/users/profile 返回当前用户信息
- [ ] PATCH /api/v1/users/profile 更新成功
- [ ] POST /api/v1/users/device_tokens 注册推送 token

---

### Day 7（周三）— 订单 CRUD API（消费者端）

**新建 OrdersController：**

```ruby
# app/controllers/api/v1/orders_controller.rb
module Api
  module V1
    class OrdersController < BaseController
      before_action :set_order, only: [:show, :cancel]

      # GET /api/v1/orders
      def index
        orders = current_user.customer_orders
                             .includes(:merchant, :order_items)
                             .order(created_at: :desc)
        render_paginated(orders, blueprint: OrderBlueprint)
      end

      # GET /api/v1/orders/:id
      def show
        authorize @order
        render_success(data: OrderBlueprint.render_as_hash(@order, view: :detail))
      end

      # POST /api/v1/orders
      def create
        order = Orders::CreateService.call(
          customer: current_user,
          params: order_params
        )
        render_success(data: OrderBlueprint.render_as_hash(order), status: :created)
      rescue Orders::CreateService::Error => e
        render_error(message: e.message)
      end

      # POST /api/v1/orders/:id/cancel
      def cancel
        authorize @order, :cancel?
        Orders::CancelService.call(@order, current_user)
        render_success(data: OrderBlueprint.render_as_hash(@order))
      rescue AASM::InvalidTransition => e
        render_error(message: '当前状态不可取消')
      end

      private

      def set_order
        @order = Order.find(params[:id])
      end

      def order_params
        params.require(:order).permit(:merchant_id, :description, :expected_at,
                                       order_items_attributes: [:name, :quantity, :price])
      end
    end
  end
end
```

**OrderBlueprint：**

```ruby
# app/blueprints/order_blueprint.rb
class OrderBlueprint < BaseBlueprint
  identifier :id
  fields :status, :total_amount, :description

  field :customer_name do |order|
    order.customer&.email
  end

  view :detail do
    association :order_items, blueprint: OrderItemBlueprint
    association :payments, blueprint: PaymentBlueprint
    field :merchant_name do |order|
      order.merchant&.email
    end
  end
end
```

**验收标准：**
- [ ] GET /api/v1/orders 返回分页订单列表
- [ ] POST /api/v1/orders 创建订单成功
- [ ] POST /api/v1/orders/:id/cancel 取消订单（状态机校验）
- [ ] Pundit 权限：只能查看自己的订单

---

### Day 8（周四）— 支付创建 API（预付单）

**支付 Controller：**

```ruby
# app/controllers/api/v1/payments_controller.rb
module Api
  module V1
    class PaymentsController < BaseController
      # POST /api/v1/payments
      # 创建支付单，返回 App 端调起支付所需参数
      def create
        order = Order.find(params[:order_id])
        authorize order, :pay?

        result = Payments::CreateService.call(
          order: order,
          channel: params[:channel],   # wechat / alipay
          user: current_user
        )

        render_success(data: result)
      rescue Payments::CreateService::Error => e
        render_error(message: e.message)
      end

      # GET /api/v1/payments/:id/status
      def status
        payment = Payment.find(params[:id])
        render_success(data: { status: payment.status, paid_at: payment.paid_at })
      end
    end
  end
end
```

**PaymentCreateService（实现预付单逻辑）：**

```ruby
# app/services/payments/create_service.rb
module Payments
  class CreateService
    class Error < StandardError; end

    def self.call(order:, channel:, user:)
      new(order: order, channel: channel, user: user).call
    end

    def call
      payment = Payment.create!(
        order: @order,
        amount: @order.total_amount,
        channel: @channel,
        status: 'pending'
      )

      case @channel
      when 'wechat'
        build_wechat_params(payment)
      when 'alipay'
        build_alipay_params(payment)
      else
        raise Error, "不支持的支付渠道: #{@channel}"
      end
    end

    private

    def build_wechat_params(payment)
      # 调用微信支付 SDK 创建预付单
      # 返回 App 端调起微信支付所需参数
      {
        payment_id: payment.id,
        channel: 'wechat',
        params: {
          # prepay_id, timeStamp, nonceStr, package, signType, paySign
          # 由微信 SDK 生成
        }
      }
    end

    def build_alipay_params(payment)
      # 调用支付宝 SDK 创建预付单
      {
        payment_id: payment.id,
        channel: 'alipay',
        params: {
          # order_string: 支付宝 SDK 所需的签名字符串
        }
      }
    end
  end
end
```

**完善支付回调 Controller（当前为 Stub）：**

```ruby
# app/controllers/api/payments/callbacks_controller.rb
module Api
  module Payments
    class CallbacksController < ActionController::API
      # POST /api/payments/callbacks/wechat
      def wechat
        # 1. 验证微信签名
        # 2. 更新 Payment 状态
        # 3. 触发 Order 状态流转
        # 4. 发送通知
        Payments::WechatCallbackService.call(request.raw_post)
        render xml: '<xml><return_code>SUCCESS</return_code></xml>'
      rescue => e
        Rails.logger.error("Wechat callback error: #{e.message}")
        render xml: '<xml><return_code>FAIL</return_code></xml>'
      end

      # POST /api/payments/callbacks/alipay
      def alipay
        Payments::AlipayCallbackService.call(params)
        render plain: 'success'
      end
    end
  end
end
```

**验收标准：**
- [ ] POST /api/v1/payments 返回微信/支付宝支付参数
- [ ] 支付回调正确更新 Payment 状态
- [ ] 支付成功后 Order 状态自动流转

---

### Day 9（周五）— 竞价 API + 通知列表 API

**竞价 API：**

```ruby
# app/controllers/api/v1/bids_controller.rb
module Api
  module V1
    class BidsController < BaseController
      # GET /api/v1/orders/:order_id/bids
      def index
        order = Order.find(params[:order_id])
        render_success(data: BidBlueprint.render_as_hash(order.bids.includes(:merchant)))
      end

      # POST /api/v1/orders/:order_id/bids
      # 注意：Bid 模型的 bidder_id 是 UUID 类型，需要通过 UuidIdentity 转换
      def create
        order = Order.find(params[:order_id])
        bid = order.bids.create!(
          bidder_id: Bid.id_to_uuid(current_user.id),
          amount: params[:amount],
          message: params[:message],
          status: 'pending'
        )
        render_success(data: BidBlueprint.render_as_hash(bid), status: :created)
      end
    end
  end
end
```

**通知列表 API：**

```bash
rails g model Notification user:references title:string body:text
                            notification_type:string read_at:datetime
                            data:jsonb
```

```ruby
# app/controllers/api/v1/notifications_controller.rb
module Api
  module V1
    class NotificationsController < BaseController
      def index
        notifications = current_user.notifications.order(created_at: :desc)
        render_paginated(notifications, blueprint: NotificationBlueprint)
      end

      def mark_read
        current_user.notifications.where(id: params[:ids]).update_all(read_at: Time.current)
        head :ok
      end
    end
  end
end
```

**验收标准：**
- [ ] 商家可以对订单出价
- [ ] 消费者可以查看订单的所有报价
- [ ] 通知列表分页返回，支持批量已读

---

## WEEK 3：商家端核心 API（5天）

> 🎯 目标：完成商家入驻、订单管理、结算等商家端核心 API

---

### Day 10（周一）— 商家入驻 API

```ruby
# app/controllers/api/v1/merchants/registrations_controller.rb
module Api
  module V1
    module Merchants
      class RegistrationsController < BaseController
        # GET /api/v1/merchants/status
        def status
          profile = current_user.merchant_profile
          if profile
            render_success(data: MerchantProfileBlueprint.render_as_hash(profile))
          else
            render_success(data: { status: 'not_applied' })
          end
        end

        # POST /api/v1/merchants/register
        def create
          authorize :merchant, :register?
          profile = MerchantProfiles::RegisterService.call(
            user: current_user,
            params: merchant_params
          )
          render_success(data: MerchantProfileBlueprint.render_as_hash(profile), status: :created)
        rescue MerchantProfiles::RegisterService::Error => e
          render_error(message: e.message)
        end

        private

        def merchant_params
          params.require(:merchant).permit(
            :business_name, :business_license, :contact_phone,
            :bank_account, :bank_name, :id_card_front, :id_card_back
          )
        end
      end
    end
  end
end
```

**验收标准：**
- [ ] POST /api/v1/merchants/register 提交入驻申请
- [ ] GET /api/v1/merchants/status 查看审核状态
- [ ] 已有 MerchantProfile 的用户不能重复申请

---

### Day 11（周二）— 商家订单管理 API

```ruby
# app/controllers/api/v1/merchants/orders_controller.rb
module Api
  module V1
    module Merchants
      class OrdersController < BaseController
        before_action :require_approved_merchant!
        before_action :set_order, only: [:show, :accept, :reject, :complete]

        # GET /api/v1/merchants/orders
        def index
          orders = current_user.merchant_orders
                               .includes(:customer, :order_items)
                               .order(created_at: :desc)
          render_paginated(orders, blueprint: OrderBlueprint)
        end

        # POST /api/v1/merchants/orders/:id/accept
        def accept
          authorize @order, :merchant_accept?
          @order.accept!
          Notifications::OrderAcceptedJob.perform_later(@order.id)
          render_success(data: OrderBlueprint.render_as_hash(@order))
        end

        # POST /api/v1/merchants/orders/:id/reject
        def reject
          authorize @order, :merchant_reject?
          @order.reject!(reason: params[:reason])
          render_success(data: OrderBlueprint.render_as_hash(@order))
        end

        # POST /api/v1/merchants/orders/:id/complete
        def complete
          authorize @order, :merchant_complete?
          @order.complete!
          render_success(data: OrderBlueprint.render_as_hash(@order))
        end

        private

        def set_order
          @order = current_user.merchant_orders.find(params[:id])
        end

        def require_approved_merchant!
          unless current_user.merchant? && current_user.merchant_profile&.approved?
            render_error(message: '需要已审核通过的商家账号', status: :forbidden)
          end
        end
      end
    end
  end
end
```

**验收标准：**
- [ ] 商家只能看到自己的订单
- [ ] 接单/拒单触发状态机流转
- [ ] 接单后自动发送通知给消费者

---

### Day 12（周三）— 商家资料管理 API

```ruby
# app/controllers/api/v1/merchants/profiles_controller.rb
# GET/PATCH /api/v1/merchants/profile
# 商家修改自己的资料（营业时间、简介、服务范围等）
```

**商家看板 API：**

```ruby
# app/controllers/api/v1/merchants/dashboard_controller.rb
module Api
  module V1
    module Merchants
      class DashboardController < BaseController
        # GET /api/v1/merchants/dashboard
        def show
          render_success(data: {
            today_orders: current_user.merchant_orders.today.count,
            pending_orders: current_user.merchant_orders.pending.count,
            this_month_revenue: current_user.merchant_orders.this_month.completed.sum(:total_amount),
            total_orders: current_user.merchant_orders.count,
            rating: current_user.merchant_profile&.average_rating
          })
        end
      end
    end
  end
end
```

**验收标准：**
- [ ] 商家可以更新自己的资料
- [ ] 看板数据正确聚合统计

---

### Day 13（周四）— 结算 API

```ruby
# app/controllers/api/v1/merchants/settlements_controller.rb
module Api
  module V1
    module Merchants
      class SettlementsController < BaseController
        before_action :require_approved_merchant!

        # GET /api/v1/merchants/settlements
        def index
          settlements = current_user.merchant_profile.settlements
                                    .order(created_at: :desc)
          render_paginated(settlements, blueprint: SettlementBlueprint)
        end

        # GET /api/v1/merchants/settlements/:id
        def show
          settlement = current_user.merchant_profile.settlements.find(params[:id])
          render_success(data: SettlementBlueprint.render_as_hash(settlement, view: :detail))
        end
      end
    end
  end
end
```

**SettlementBlueprint：**

```ruby
class SettlementBlueprint < BaseBlueprint
  identifier :id
  fields :amount, :status, :period_start, :period_end, :settled_at

  view :detail do
    field :orders_count do |s|
      s.orders.count
    end
    field :platform_fee do |s|
      s.platform_fee
    end
  end
end
```

**验收标准：**
- [ ] 商家可以查看结算记录列表
- [ ] 结算详情包含订单数和平台手续费

---

### Day 14（周五）— 商家端 API 集成测试 + 文档

```bash
# 运行商家端全部测试
bundle exec rspec spec/requests/api/v1/merchants/

# 生成 Swagger 文档
bundle exec rails rswag:specs:swaggerize
```

**补充 Rswag 文档注释（关键 API）：**

```ruby
# spec/requests/api/v1/merchants/orders_spec.rb
RSpec.describe 'Merchants Orders API' do
  path '/api/v1/merchants/orders' do
    get '商家订单列表' do
      tags 'Merchant Orders'
      security [bearerAuth: []]
      parameter name: :page, in: :query, type: :integer
      # ...
    end
  end
end
```

**验收标准：**
- [ ] 商家端全部 RSpec 测试通过
- [ ] Swagger 文档更新，前端可查阅
- [ ] Postman Collection 导出备用

---

## WEEK 4：扩展功能（5天）

> 🎯 目标：推送通知、工单系统、实时通信、国际化

---

### Day 15（周一）— 推送通知集成（Expo Push）

**安装依赖：**

```ruby
# Gemfile
gem 'exponent-server-sdk'  # Expo Push Notifications
```

**推送 Service：**

```ruby
# app/services/notifications/push_service.rb
module Notifications
  class PushService
    def self.send_to_user(user, title:, body:, data: {})
      tokens = user.device_tokens.pluck(:token)
      return if tokens.empty?

      client = Exponent::Push::Client.new
      messages = tokens.map do |token|
        {
          to: token,
          title: title,
          body: body,
          data: data,
          sound: 'default'
        }
      end

      client.publish(messages)
    rescue => e
      Rails.logger.error("Push notification failed: #{e.message}")
      Sentry.capture_exception(e)
    end
  end
end
```

**推送 Job：**

```ruby
# app/jobs/notifications/order_accepted_job.rb
module Notifications
  class OrderAcceptedJob < ApplicationJob
    queue_as :notifications

    def perform(order_id)
      order = Order.find(order_id)
      Notifications::PushService.send_to_user(
        order.customer,
        title: '订单已接受',
        body: "您的订单已被商家接受",
        data: { order_id: order.id, type: 'order_accepted' }
      )
      # 同时创建站内通知
      order.customer.notifications.create!(
        title: '订单已接受',
        body: "您的订单已被商家接受",
        notification_type: 'order_accepted',
        data: { order_id: order.id }
      )
    end
  end
end
```

**验收标准：**
- [ ] 测试环境 Expo Push 发送成功
- [ ] 订单状态变更自动触发推送
- [ ] 推送失败不影响主流程（异步 + 错误捕获）

---

### Day 16（周二）— 工单系统 API

> ✅ 模型已存在（Ticket + TicketMessage + TicketAttachment），只需写 API 层
> ⚠️ 注意：User 模型没有 `has_many :tickets` 关联，且 Ticket.creator_id 是 UUID 类型
> 需要通过 UuidIdentity concern 进行查询

```ruby
# app/controllers/api/v1/tickets_controller.rb
module Api
  module V1
    class TicketsController < BaseController
      before_action :set_ticket, only: [:show, :messages, :create_message, :close]

      # GET /api/v1/tickets
      # User 没有 has_many :tickets，需要通过 UUID 查询
      def index
        tickets = Ticket.where(creator_id: Ticket.id_to_uuid(current_user.id))
                        .order(created_at: :desc)
        render_paginated(tickets, blueprint: TicketBlueprint)
      end

      # POST /api/v1/tickets
      def create
        ticket = Ticket.create!(ticket_params.merge(
          creator_id: Ticket.id_to_uuid(current_user.id),
          creator_type: 'User'
        ))
        render_success(data: TicketBlueprint.render_as_hash(ticket), status: :created)
      end

      # GET /api/v1/tickets/:id/messages
      def messages
        render_success(data: TicketMessageBlueprint.render_as_hash(@ticket.messages))
      end

      # POST /api/v1/tickets/:id/messages
      def create_message
        message = @ticket.messages.create!(
          sender_id: TicketMessage.id_to_uuid(current_user.id),
          content: params[:content]
        )
        render_success(data: TicketMessageBlueprint.render_as_hash(message), status: :created)
      end

      # PATCH /api/v1/tickets/:id/close
      def close
        @ticket.close!
        render_success(data: TicketBlueprint.render_as_hash(@ticket))
      end

      private

      def set_ticket
        @ticket = Ticket.where(creator_id: Ticket.id_to_uuid(current_user.id))
                        .find(params[:id])
      end

      def ticket_params
        params.require(:ticket).permit(:subject, :category, :priority)
      end
    end
  end
end
```

**验收标准：**
- [ ] 用户可以创建工单
- [ ] 工单消息支持多轮对话
- [ ] 附件上传（ActiveStorage）

---

### Day 17（周三）— ActionCable 实时推送

**配置 ActionCable 使用 Redis：**

```ruby
# config/cable.yml
production:
  adapter: redis
  url: <%= ENV['REDIS_URL'] %>

development:
  adapter: redis
  url: redis://localhost:6379/1
```

**订单状态 Channel：**

```ruby
# app/channels/order_status_channel.rb
class OrderStatusChannel < ApplicationCable::Channel
  def subscribed
    order = Order.find(params[:order_id])
    # 验证订阅权限
    if order.customer == current_user || order.merchant == current_user
      stream_for order
    else
      reject
    end
  end
end

# ActionCable Connection 的 JWT 认证
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      token = request.params[:token] || request.headers['Authorization']&.delete_prefix('Bearer ')
      payload = Auth::JwtVerifier.verify!(token)
      User.find_by!(external_id: payload['sub'])
    rescue => e
      reject_unauthorized_connection
    end
  end
end
```

**广播订单状态变更：**

```ruby
# app/models/order.rb（添加 after_commit 回调）
after_commit :broadcast_status_change, on: :update, if: :saved_change_to_status?

def broadcast_status_change
  OrderStatusChannel.broadcast_to(self, {
    order_id: id,
    status: status,
    updated_at: updated_at.iso8601
  })
end
```

**验收标准：**
- [ ] App 端 WebSocket 连接成功（带 JWT token）
- [ ] 订单状态变更实时推送到 App
- [ ] 非授权用户无法订阅他人订单

---

### Day 18（周四）— i18n 国际化 + API 响应本地化

**配置 i18n：**

```ruby
# config/application.rb
config.i18n.available_locales = [:zh, :'zh-CN', :en]
config.i18n.default_locale = :'zh-CN'
config.i18n.fallbacks = true
```

**根据用户 locale 自动切换：**

```ruby
# app/controllers/api/v1/base_controller.rb
before_action :set_locale

def set_locale
  locale = current_user&.locale || request.headers['Accept-Language']&.split(',')&.first || 'zh-CN'
  I18n.locale = locale.to_sym
rescue I18n::InvalidLocale
  I18n.locale = :'zh-CN'
end
```

**错误消息国际化：**

```yaml
# config/locales/api.zh-CN.yml
zh-CN:
  api:
    errors:
      unauthorized: "请先登录"
      forbidden: "权限不足"
      not_found: "资源不存在"
      order:
        cannot_cancel: "当前状态无法取消订单"
        not_found: "订单不存在"

# config/locales/api.en.yml
en:
  api:
    errors:
      unauthorized: "Please sign in first"
      forbidden: "Access denied"
```

**验收标准：**
- [ ] 中文用户收到中文错误消息
- [ ] 海外用户收到英文错误消息
- [ ] 语言根据 User.locale 自动切换

---

### Day 19（周五）— 安全加固 + Rate Limiting

> ✅ `rack-attack` gem 已在 Gemfile 中（L30），无需重新安装
> 需要检查是否已有 initializer 配置，如没有则新建

```ruby
# config/initializers/rack_attack.rb（新建或更新）
class Rack::Attack
  # 限制 API 请求频率
  throttle('api/ip', limit: 300, period: 5.minutes) do |req|
    req.ip if req.path.start_with?('/api/')
  end

  # 限制支付创建（更严格）
  throttle('payments/user', limit: 10, period: 1.minute) do |req|
    req.env['current_user_id'] if req.path.include?('/payments')
  end

  # 限制 Webhook 调用频率
  throttle('webhooks/ip', limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api/webhooks/')
  end

  # 封禁恶意 IP
  blocklist('block bad ips') do |req|
    BlockedIp.exists?(ip: req.ip) if defined?(BlockedIp)
  end
end
```

**API 版本控制确认：**

```ruby
# 确认所有路由都在 /api/v1/ 命名空间下
# 为未来 v2 预留扩展点
```

**验收标准：**
- [ ] API 限流生效（超限返回 429）
- [ ] 敏感接口有额外限制
- [ ] 安全 Headers 配置正确

---

## WEEK 5-6：联调 + 性能优化 + 部署（7天）

> 🎯 目标：全链路联调，性能达标，生产环境部署

---

### Day 20-21（周一-周二）— 前后端联调（认证 + 用户端）

**联调清单：**

```
认证流程：
- [ ] Logto 登录 → 获取 Access Token → 请求 API → 自动创建本地用户
- [ ] Token 过期 → App 端刷新 → 继续请求
- [ ] 微信登录（国内用户）完整流程
- [ ] Apple 登录（海外用户）完整流程

用户端流程：
- [ ] 查看/编辑个人资料
- [ ] 创建订单 → 选择支付方式 → 调起支付 → 支付成功
- [ ] 查看订单列表 → 订单详情 → 取消订单
- [ ] 接收推送通知（订单状态变更）
- [ ] WebSocket 实时状态更新
```

---

### Day 22-23（周三-周四）— 前后端联调（商家端）

```
商家端流程：
- [ ] 商家入驻申请 → 提交资料 → 等待审核
- [ ] 审核通过通知 → 进入商家端
- [ ] 查看待接订单 → 接单/拒单
- [ ] 查看结算记录
- [ ] 商家看板数据展示
```

---

### Day 24（周五）— 性能优化

**N+1 查询检查：**

```ruby
# Gemfile（开发环境）
gem 'bullet', group: :development

# 检查并修复所有 N+1 查询
# 重点：订单列表（关联 customer、merchant、order_items）
```

**数据库索引优化：**

```ruby
# 检查慢查询，补充索引
add_index :orders, [:customer_id, :status]
add_index :orders, [:merchant_id, :status]
add_index :notifications, [:user_id, :read_at]
add_index :payments, :order_id
```

**API 响应时间目标：**

| 接口 | 目标响应时间 |
|------|------------|
| GET /api/v1/orders | < 200ms |
| GET /api/v1/merchants/dashboard | < 300ms |
| POST /api/v1/payments | < 500ms |

---

### Day 25（下周一）— 生产环境部署 + 监控

**部署 Checklist：**

```
Logto 部署：
- [ ] Logto Cloud → 自部署迁移（国内服务器）
- [ ] 微信 OAuth 回调域名配置
- [ ] Apple Sign-in 域名配置

Rails 部署：
- [ ] 环境变量配置（LOGTO_ENDPOINT, LOGTO_API_RESOURCE 等）
- [ ] Sidekiq 队列配置（notifications, payments, default）
- [ ] ActionCable Redis adapter 配置
- [ ] CORS 配置更新（添加 App 的 scheme）

监控：
- [ ] Sentry 错误追踪（已有，确认 DSN 配置）
- [ ] 关键 API 响应时间监控
- [ ] Sidekiq 队列监控
```

**验收标准：**
- [ ] 生产环境全链路测试通过
- [ ] Sentry 无异常报错
- [ ] 关键接口响应时间达标

---

### Day 26（周二）— 文档 + 收尾

```
- [ ] Swagger/Rswag 文档最终更新
- [ ] README 更新（本地开发启动指南）
- [ ] 环境变量文档（.env.example 更新）
- [ ] 数据库 Schema 文档更新
- [ ] 已知问题和技术债记录
```

---

## 📊 工期总览

| 阶段 | 时间 | 工作日 | 核心交付 |
|------|------|--------|---------|
| Week 0 | 第1周 Mon-Tue | 2天 | UuidIdentity 规范化 + Devise 审计 |
| Week 1 | 第1周 Wed - 第2周 Wed | 6天 | Logto JWT 认证 + 已有 Controller 迁移 |
| Week 2 | 第2周 Thu - 第3周 Wed | 5天 | 用户端核心 API |
| Week 3 | 第3周 Thu - 第4周 Wed | 5天 | 商家端核心 API |
| Week 4 | 第4周 Thu - 第5周 Wed | 5天 | 推送+工单+ActionCable+i18n+安全加固 |
| Week 5-6 | 第5周 Thu - 第6周 Fri | 7天 | 联调+优化+部署 |
| **合计** | | **30天（6周）** | |

---

## 🚫 本期范围外（v2 计划）

| 功能 | 原因 |
|------|------|
| Stripe 海外支付 | 1天不够，推至 v2 |
| GraphQL API | 可选优化，REST 已够用 |
| 订阅/会员系统（RevenueCat） | 需确认业务需求后再排期 |
| 商家评价系统 | 核心流程稳定后再加 |

---

## 📎 附录：关键环境变量清单

```bash
# Logto
LOGTO_ENDPOINT=https://your-tenant.logto.app
LOGTO_API_RESOURCE=https://api.craftlet.com
LOGTO_JWKS_URI=https://your-tenant.logto.app/oidc/jwks
LOGTO_WEBHOOK_SECRET=your-webhook-secret

# 微信支付
WECHAT_APP_ID=
WECHAT_MCH_ID=
WECHAT_API_KEY=

# 支付宝
ALIPAY_APP_ID=
ALIPAY_PRIVATE_KEY=
ALIPAY_PUBLIC_KEY=

# Expo Push
EXPO_ACCESS_TOKEN=

# 已有
REDIS_URL=
DATABASE_URL=
SENTRY_DSN=
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_BUCKET=
```

---

*文档版本：v2.1（终版）*
*更新时间：2026-04-13*
*基于：app_architecture_analysis.md + 评估.md + 代码库深度审计（schema.rb UUID 列全量扫描）*
*修正点：UUID 方案 E 替换方案 A、soft_delete→disable、6 Controller 迁移、Bid/Ticket 参数修正*
