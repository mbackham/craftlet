# Craftlet Week 0 测试手册 / Test Manual
## 数据层修复 + Devise 审计 | Data Layer Fix + Devise Audit

**版本 Version：** 1.0  
**日期 Date：** 2026-04-13  
**对应开发计划 Dev Plan：** Logto2.md — Week 0（Day 0a + Day 0b）  
**测试环境 Test Env：** Development / Staging  
**前置条件 Prerequisite：** `bundle exec rails db:migrate` 已执行成功 / migration executed successfully

---

## 1. 测试范围 / Test Scope

| 模块 Module | 变更内容 Change | 测试类型 Test Type |
|---|---|---|
| `UuidIdentity` Concern | 新建，统一 UUID↔bigint 转换 / New concern for unified UUID↔bigint conversion | 单元 Unit + 集成 Integration |
| `Order` 模型 Model | 新增 `#customer`, `#merchant` 方法，别名保留 / New methods with backward-compat aliases | 单元 Unit |
| `Bid` 模型 Model | 新增 `#bidder` 方法和 setter / New `#bidder` method and setter | 单元 Unit |
| `Ticket` 模型 Model | `#creator`, `#assignee` 改用 concern / Methods now use concern | 单元 Unit |
| `TicketMessage` 模型 | `#sender` 改用 concern / Method now uses concern | 单元 Unit |
| `MerchantProfile` 模型 | `#approved_by_admin`, `#rejected_by_admin` 改用 concern / Methods use concern | 单元 Unit |
| `MerchantReviewLog` 模型 | `#operator` 改用 concern / Method uses concern | 单元 Unit |
| `AuditLog` 模型 | `#actor` 改用 concern / Method uses concern | 单元 Unit |
| `RiskEvent` 模型 | `#subject`, `#resolved_by` 改用 concern / Methods use concern | 单元 Unit |
| `Refund` 模型 | `#requester` 改用 concern / Method uses concern | 单元 Unit |
| DB Migration | users 表新增字段，放宽约束 / New columns and relaxed constraints | 数据库 DB |
| User 模型 Devise | 移除 `:jwt_authenticatable`, `:validatable`, `:registerable` | 配置 Config |
| AdminUser 功能 | 确认 AdminUser 登录和权限不受影响 / Confirm unchanged | 回归 Regression |

---

## 2. 自动化测试（RSpec）/ Automated Tests

### 2.1 执行命令 / Run Commands

```bash
# 运行 Week 0 相关测试（重点）
# Run Week 0 focused tests (primary)
bundle exec rspec spec/models/concerns/uuid_identity_spec.rb --format documentation

# 运行全量回归测试
# Run full regression suite
bundle exec rspec --format progress

# 运行 AdminUser 相关测试
# Run AdminUser-related tests
bundle exec rspec spec/models/admin_user_spec.rb --format documentation
```

### 2.2 预期结果 / Expected Results

| 测试文件 Test File | 预期 Expected | 备注 Note |
|---|---|---|
| `spec/models/concerns/uuid_identity_spec.rb` | **34 passed, 0 failures** | 核心测试（含 customer_orders/merchant_orders 回归守卫）/ Core tests incl. order relation regression guard |
| `spec/models/admin_user_spec.rb` | 全部通过 / All pass | 回归 / Regression |
| `spec/models/ticket_spec.rb` | 全部通过 / All pass | 回归 / Regression |
| `spec/requests/api/v1/users/sessions_spec.rb` | ⚠️ 3 failures（预期）| sign_in/sign_out 路由已移除（Week 0 计划内）/ Routes deliberately removed |
| `spec/models/fund_alert_spec.rb` | ⚠️ Pre-existing failures | 与本次改动无关 / Unrelated to this change |

> ⚠️ **说明 Note：** `sessions_spec` 的 3 个失败是**计划内**的，因为 `POST /api/v1/users/sign_in` 和 `DELETE /api/v1/users/sign_out` 路由已在 Week 0 移除。这些接口在 Week 1 将由 Logto JWT 替代。  
> ⚠️ The 3 `sessions_spec` failures are **intentional**. The `POST /api/v1/users/sign_in` and `DELETE /api/v1/users/sign_out` routes were deliberately removed in Week 0. They will be replaced by Logto JWT in Week 1.

---

## 3. 手动测试用例 / Manual Test Cases

---

### 📦 TC-01 数据库迁移验证 / Database Migration Verification

**目的 Purpose：** 确认 Migration 执行后 users 表结构正确  
**Confirm the users table structure is correct after migration**

**步骤 Steps：**

```bash
# 进入 Rails 控制台
bundle exec rails console

# 检查 users 表字段
ActiveRecord::Base.connection.columns('users').map { |c| [c.name, c.type, c.null, c.default] }
```

**验收标准 Acceptance Criteria：**

| 字段 Column | 类型 Type | Nullable | Default |
|---|---|---|---|
| `encrypted_password` | string | ✅ `true`（可空 nullable） | `nil` |
| `jti` | string | ✅ `true`（可空 nullable） | — |
| `external_id` | string | ✅ `true` | `nil` |
| `auth_provider` | string | ✅ `true` | `"logto"` |
| `locale` | string | ✅ `true` | `"zh-CN"` |
| `country_code` | string | ✅ `true` | `nil` |

**索引验证 Index Check：**

```bash
# 检查 external_id 唯一索引
ActiveRecord::Base.connection.indexes('users').find { |i| i.name == 'index_users_on_external_id' }
# 预期输出：unique: true
```

---

### 📦 TC-02 UuidIdentity 转换逻辑验证 / UuidIdentity Conversion Logic

**目的 Purpose：** 验证 UUID↔bigint 双向转换的正确性  
**Validate bidirectional UUID↔bigint conversion**

**步骤 Steps：**

```bash
bundle exec rails console
```

```ruby
# 2a. bigint → UUID 编码
Order.id_to_uuid(42)
# 预期 Expected: "00000000-0000-0000-0000-000000000042"

Order.id_to_uuid(1)
# 预期 Expected: "00000000-0000-0000-0000-000000000001"

Order.id_to_uuid(nil)
# 预期 Expected: nil

Order.id_to_uuid("")
# 预期 Expected: nil

# 2b. UUID → bigint 解码
Order.uuid_to_id("00000000-0000-0000-0000-000000000042")
# 预期 Expected: 42

Order.uuid_to_id(nil)
# 预期 Expected: nil

# 2c. 往返一致性（Round-trip）
id = 12345
Order.uuid_to_id(Order.id_to_uuid(id)) == id
# 预期 Expected: true

# 2d. 各模型均已 include UuidIdentity
[Order, Bid, Ticket, TicketMessage, MerchantProfile, MerchantReviewLog,
 AuditLog, RiskEvent, Refund].all? { |klass| klass.include?(UuidIdentity) }
# 预期 Expected: true
```

---

### 📦 TC-03 Order 模型关联验证 / Order Model Association

**目的 Purpose：** 验证 Order 的 `#customer` / `#merchant` 方法（替换旧 `#customer_user` / `#merchant_user`）  
**Validate Order's `#customer` / `#merchant` methods (replacing old `#customer_user` / `#merchant_user`)**

**步骤 Steps：**

```bash
bundle exec rails console
```

```ruby
# 确认有测试数据
u = User.first  # 取一个现有用户 / Use an existing user
o = Order.first # 取一个现有订单 / Use an existing order

# 3a. customer 查找（通过 UUID 列）
Order.find_by("customer_id IS NOT NULL")&.customer
# 预期 Expected: 返回对应 User 对象 / Returns corresponding User object

# 3b. merchant 查找（通过 UUID 列）
Order.find_by("merchant_id IS NOT NULL")&.merchant
# 预期 Expected: 返回对应 User 对象 / Returns corresponding User object

# 3c. 向下兼容别名（ActiveAdmin 使用了这些旧方法名）
# Backward-compatible aliases (ActiveAdmin uses these old method names)
order = Order.find_by("customer_id IS NOT NULL")
order.customer == order.customer_user
# 预期 Expected: true

order.merchant == order.merchant_user
# 预期 Expected: true

# 3d. blank customer_id 返回 nil
Order.new(customer_id: nil).customer
# 预期 Expected: nil

# 3e. customer= setter
order = Order.new
user = User.first
order.customer = user
order.customer_id == Order.id_to_uuid(user.id)
# 预期 Expected: true
```

---

### 📦 TC-03b User 订单关联验证（Issue 1 修复）/ User Order Relation Fix Validation

**目的 Purpose：** 验证 `user.customer_orders` / `user.merchant_orders` 返回正确结果，不再受 has_many bigint 类型不匹配影响  
**Validate that `user.customer_orders` / `user.merchant_orders` return correct results, no longer affected by has_many bigint type mismatch**

> ⚠️ **关键回归测试** — has_many 版本会永远返回空集合；方法版本使用 UUID 查询，必须有数据时才返回非空。  
> ⚠️ **Critical regression test** — has_many version always returns empty; method version uses UUID query and must return results when data exists.

```ruby
# 前提：存在有效订单（customer_id 使用 UUID 格式写入）
# Prerequisite: valid order exists (customer_id written in UUID format)
user = User.first

# 3b-1. customer_orders 应返回非空（若该用户有订单）
user.customer_orders.count
# 预期 Expected: >= 0（若有数据应 > 0，不应永远为 0）

# 3b-2. 生成的 SQL 应包含 UUID 格式的 id（不是 bigint）
user.customer_orders.to_sql
# 预期 Expected: SQL 中 customer_id = '00000000-0000-0000-0000-XXXXXXXXXXXX'
# NOT Expected:  customer_id = 42（bigint 格式）

# 3b-3. merchant_orders 同理
user.merchant_orders.to_sql
# 预期 Expected: SQL 中 merchant_id = '00000000-0000-0000-0000-XXXXXXXXXXXX'

# 3b-4. 支持链式调用（与 has_many 行为兼容）
user.customer_orders.where(status: 'created').count
# 预期 Expected: 整数（无报错）/ Integer (no error)

user.customer_orders.order(created_at: :desc).limit(5)
# 预期 Expected: ActiveRecord::Relation（无报错）/ Relation (no error)
```

---

### 📦 TC-04 Bid 模型验证 / Bid Model Validation

```ruby
# 4a. bidder 查找
Bid.find_by("bidder_id IS NOT NULL")&.bidder
# 预期 Expected: 返回对应 User 对象 / Returns User object

# 4b. bidder= setter
bid = Bid.new
user = User.first
bid.bidder = user
bid.bidder_id == Bid.id_to_uuid(user.id)
# 预期 Expected: true

# 4c. blank bidder_id
Bid.new(bidder_id: nil).bidder
# 预期 Expected: nil
```

---

### 📦 TC-05 Ticket 模型验证 / Ticket Model Validation

```ruby
# 5a. creator 查找（User 类型）
t = Ticket.where(creator_type: "User").find_by("creator_id IS NOT NULL")
t&.creator
# 预期 Expected: 返回对应 User 对象 / Returns User object

# 5b. creator 查找（AdminUser 类型）
t = Ticket.where(creator_type: "AdminUser").find_by("creator_id IS NOT NULL")
t&.creator
# 预期 Expected: 返回对应 AdminUser 对象 / Returns AdminUser object（如有数据 if data exists）

# 5c. assignee 查找
t = Ticket.find_by("assignee_id IS NOT NULL")
t&.assignee
# 预期 Expected: 返回对应 AdminUser 对象 / Returns AdminUser object

# 5d. nil 处理
Ticket.new.creator
# 预期 Expected: nil
```

---

### 📦 TC-06 MerchantProfile 管理员关联验证 / MerchantProfile Admin Association

```ruby
# 6a. approved_by_admin
mp = MerchantProfile.find_by("approved_by_admin_id IS NOT NULL")
mp&.approved_by_admin
# 预期 Expected: 返回对应 AdminUser 对象 / Returns AdminUser object

# 6b. rejected_by_admin
mp = MerchantProfile.find_by("rejected_by_admin_id IS NOT NULL")
mp&.rejected_by_admin
# 预期 Expected: 返回对应 AdminUser 对象 / Returns AdminUser object

# 6c. format_admin_id_as_uuid 仍可用（向下兼容）
# format_admin_id_as_uuid still works (backward-compat)
MerchantProfile.format_admin_id_as_uuid(1)
# 预期 Expected: "00000000-0000-0000-0000-000000000001"
```

---

### 📦 TC-07 MerchantReviewLog 操作员验证 / MerchantReviewLog Operator Validation

```ruby
# 7a. operator 查找
log = MerchantReviewLog.find_by("operator_admin_id IS NOT NULL")
log&.operator
# 预期 Expected: 返回对应 AdminUser 对象 / Returns AdminUser object

# 7b. operator_display_name
log&.operator_display_name
# 预期 Expected: 返回 AdminUser 的 email 字符串 / Returns AdminUser's email string

# 7c. format_admin_id_as_uuid 仍可用
MerchantReviewLog.format_admin_id_as_uuid(42)
# 预期 Expected: "00000000-0000-0000-0000-000000000042"
```

---

### 📦 TC-08 AuditLog Actor 验证 / AuditLog Actor Validation

```ruby
# 8a. User 类型 actor
log = AuditLog.where(actor_type: "User").find_by("actor_id IS NOT NULL")
log&.actor
# 预期 Expected: 返回对应 User 对象 / Returns User object

# 8b. AdminUser 类型 actor
log = AuditLog.where(actor_type: "AdminUser").find_by("actor_id IS NOT NULL")
log&.actor
# 预期 Expected: 返回对应 AdminUser 对象 / Returns AdminUser object

# 8c. System 类型返回 nil
AuditLog.new(actor_type: "System", actor_id: "some-uuid").actor
# 预期 Expected: nil
```

---

### 📦 TC-09 RiskEvent 验证 / RiskEvent Validation

```ruby
# 9a. subject 查找
re = RiskEvent.find_by("subject_id IS NOT NULL")
re&.subject
# 预期 Expected: 返回 User 对象 / Returns User object

# 9b. resolved_by 查找
re = RiskEvent.find_by("resolved_by_id IS NOT NULL")
re&.resolved_by
# 预期 Expected: 返回 AdminUser 对象 / Returns AdminUser object
```

---

### 📦 TC-10 Refund 验证 / Refund Validation

```ruby
# 10a. requester 查找
r = Refund.find_by("requested_by_id IS NOT NULL")
r&.requester
# 预期 Expected: 返回 User 对象 / Returns User object

# 10b. nil 处理
Refund.new(requested_by_id: nil).requester
# 预期 Expected: nil
```

---

### 📦 TC-11 旧 Hack 代码消除验证 / Legacy Hack Code Elimination

**目的 Purpose：** 确认所有散落的 `split('-').last.to_i` 已从模型层消除  
**Confirm all scattered `split('-').last.to_i` patterns are removed from model layer**

```bash
# 在项目根目录执行 / Run in project root
grep -rn "split('-').last.to_i" app/models/ --include="*.rb"
# 预期 Expected: 0 条结果（无输出）/ 0 results (no output)

# 检查 services 层（非模型的 UUID hack）
grep -rn "split('-').last.to_i\|split(\"-\").last.to_i" app/services/ --include="*.rb"
# 预期 Expected: 0 条结果 / 0 results
```

---

### 📦 TC-12 User 模型 Devise 配置验证 / User Model Devise Configuration

**目的 Purpose：** 验证 `:jwt_authenticatable`, `:validatable`, `:registerable` 已移除  
**Verify `:jwt_authenticatable`, `:validatable`, `:registerable` are removed**

```bash
bundle exec rails console
```

```ruby
# 12a. User 不再有 JWT 认证策略
User.devise_modules
# 预期 Expected: 包含 :database_authenticatable, :recoverable, :rememberable, :lockable, :trackable
# 预期 NOT 包含: :jwt_authenticatable, :validatable, :registerable

# 12b. User 不再需要密码即可创建（encrypted_password 可 nil）
u = User.new(email: "test_logto_#{Time.now.to_i}@test.com", status: "active")
u.valid?
# 预期 Expected: true（无 encrypted_password 相关验证错误）
# Expected: true (no encrypted_password validation error)
u.errors.full_messages
# 预期 Expected: 不包含密码相关错误 / No password-related errors

# 12c. 确认 JTIMatcher 已移除
User.ancestors.include?(Devise::JWT::RevocationStrategies::JTIMatcher)
# 预期 Expected: false
```

---

### 📦 TC-13 AdminUser 登录回归测试 / AdminUser Login Regression

**目的 Purpose：** 确认 AdminUser 的 Devise 登录功能完全不受影响  
**Confirm AdminUser Devise login is completely unaffected**

**步骤 Steps（浏览器手动操作 Browser Manual）：**

1. 访问 / Navigate to: `http://localhost:3000/admin`
2. 确认登录页面正常显示 / Confirm login page renders correctly
3. 使用管理员账号登录 / Sign in with admin credentials
4. 确认可以正常进入 AdminUser 后台 / Confirm successful admin panel access
5. 导航到 Users 列表 / Navigate to Users list
6. 确认 User 列表正常加载，无报错 / Confirm User list loads without errors

**Rails Console 验证：**

```ruby
# AdminUser 的 Devise 模块完整性
AdminUser.devise_modules
# 预期 Expected: [:database_authenticatable, :recoverable, :rememberable,
#                 :validatable, :lockable, :trackable, :timeoutable]

# AdminUser 密码验证仍生效
admin = AdminUser.new(email: "test@test.com", password: "weak", role: "admin")
admin.valid?
# 预期 Expected: false（密码强度不足 / password too weak）
admin.errors.full_messages.any? { |m| m.include?("密码") || m.include?("password") }
# 预期 Expected: true
```

---

### 📦 TC-14 路由验证 / Route Validation

**目的 Purpose：** 验证路由改动符合预期  
**Verify route changes are as expected**

```bash
# 检查路由表
bundle exec rails routes 2>&1 | grep -E "admin|sign_in|sign_out|password"
```

**预期 Expected：**

| 路由 Route | 状态 Status |
|---|---|
| `POST /api/v1/users/sign_in` | ❌ 已移除 Removed（Week 0 计划内）|
| `DELETE /api/v1/users/sign_out` | ❌ 已移除 Removed（Week 0 计划内）|
| `GET /admin` | ✅ 存在 Present |
| `POST /admin/sign_in` / `DELETE /admin/sign_out` | ✅ 存在 Present（AdminUser）|
| `/users/password/*` | ✅ 存在 Present（密码重置）|

---

### 📦 TC-15 ActiveAdmin 功能完整性 / ActiveAdmin Functional Integrity

**目的 Purpose：** 确认 ActiveAdmin 各功能模块不受影响  
**Confirm all ActiveAdmin modules are unaffected**

**步骤 Steps（浏览器手动 Browser Manual）：**

1. 登录 ActiveAdmin / Login to ActiveAdmin
2. **订单管理（Orders）：**
   - 打开订单列表 / Open Orders list
   - 确认 "买家" 列显示邮箱（`customer_user&.email`）/ Confirm "Buyer" column shows email
   - 确认 "商家" 列显示邮箱（`merchant_user&.email`）/ Confirm "Merchant" column shows email
   - 点击某订单 → 查看详情页 / Click an order → view detail page
   - 确认 "买家" 和 "商家" 字段正确展示 / Confirm buyer and merchant fields display correctly
3. **商家管理（Merchants）：**
   - 打开商家申请列表 / Open merchant application list
   - 如有数据，确认审核人字段正常显示 / Confirm approver/reviewer fields show correctly
4. **工单管理（Tickets）：**
   - 打开工单列表 / Open tickets list
   - 确认创建人/处理人字段正常 / Confirm creator/assignee fields are correct
5. **User 列表：**
   - 确认 User 列表无报错加载 / Confirm User list loads without errors
   - 确认新字段（`external_id`, `auth_provider`, `locale`, `country_code`）可见 / Confirm new columns are visible

---

### 📦 TC-16 AssignMerchantService 验证 / AssignMerchantService Validation

**目的 Purpose：** 验证 AssignMerchantService 的 UUID 格式化逻辑已委托给 UuidIdentity  
**Verify AssignMerchantService UUID formatting delegates to UuidIdentity**

```ruby
# 验证 format_user_id_as_uuid 结果与 UuidIdentity 一致
require_relative 'app/services/orders/assign_merchant_service'

# 直接测试（在 console 中）
service = Orders::AssignMerchantService.new(
  order: Order.new,
  merchant_user: User.new(id: 42),
  admin_user: AdminUser.new
)
# 内部方法（私有）通过 send 访问
service.send(:format_user_id_as_uuid, 42) == Order.id_to_uuid(42)
# 预期 Expected: true
```

---

## 4. 回归测试矩阵 / Regression Test Matrix

| 测试场景 Test Scenario | 操作 Action | 预期 Expected | 优先级 Priority |
|---|---|---|---|
| UUID → bigint 编码正确 | `Order.id_to_uuid(42)` | `"00000000-0000-0000-0000-000000000042"` | 🔴 High |
| bigint → UUID 解码正确 | `Order.uuid_to_id("...000042")` | `42` | 🔴 High |
| Order#customer 解析正确 | 查找有效订单 | 返回对应 User | 🔴 High |
| Order#customer_user 别名有效 | 调用旧方法名 | 等同 `#customer` | 🔴 High |
| Bid#bidder 解析正确 | 查找有效 Bid | 返回对应 User | 🔴 High |
| Ticket#creator 解析正确（User） | creator_type = User | 返回 User | 🔴 High |
| Ticket#creator 解析正确（Admin） | creator_type = AdminUser | 返回 AdminUser | 🔴 High |
| MerchantProfile#approved_by_admin | 有审核记录 | 返回 AdminUser | 🟡 Medium |
| AuditLog#actor（User） | actor_type = User | 返回 User | 🟡 Medium |
| AuditLog#actor（System） | actor_type = System | 返回 nil | 🟡 Medium |
| encrypted_password 可为 nil | User.create! 不传密码 | 创建成功 | 🔴 High |
| external_id 唯一索引 | 重复 external_id | 报 uniqueness 错误 | 🔴 High |
| AdminUser 登录正常 | 浏览器登录 /admin | 成功进入后台 | 🔴 High |
| AdminUser 密码验证仍生效 | 弱密码创建 AdminUser | 验证失败 | 🔴 High |
| 旧 sign_in 路由已移除 | POST /api/v1/users/sign_in | 404 / 路由不存在 | 🟡 Medium |
| AdminUser 路由正常 | GET /admin/sign_in | 200 | 🔴 High |
| RSpec uuid_identity_spec | `bundle exec rspec spec/models/concerns/uuid_identity_spec.rb` | 27 passed, 0 failures | 🔴 High |

---

## 5. 已知问题 / Known Issues

| ID | 描述 Description | 严重级 Severity | 是否计划内 Planned | 解决时间 Resolution |
|---|---|---|---|---|
| KI-01 | `POST /api/v1/users/sign_in` 路由已移除，`sessions_spec` 3 个测试失败 / Route removed, 3 sessions_spec tests fail | Medium | ✅ 是 Yes | Week 1 — 将由 Logto JWT 端点替代 / Replaced by Logto JWT endpoint |
| KI-02 | `fund_alert_spec` 11 个测试失败（Payment factory 问题）/ 11 tests fail (Payment factory issue) | Low | ✅ 预存在 Pre-existing | 与本次改动无关 / Unrelated to this change |
| KI-03 | `jti` 字段的唯一索引仍存在（schema 中），但 jti 值不再写入 / jti unique index still exists | Low | ✅ 是 Yes | Week 1 — 移除 devise-jwt gem 后可选删除索引 / Index can be dropped after gem removal |

---

## 6. 文件变更清单 / File Change Summary

| 文件 File | 变更类型 Change Type | 说明 Description |
|---|---|---|
| `app/models/concerns/uuid_identity.rb` | 🆕 新建 New | UUID↔bigint 统一转换 Concern |
| `app/models/order.rb` | ✏️ 修改 Modified | 引入 UuidIdentity，新增 setter，添加别名 |
| `app/models/bid.rb` | ✏️ 修改 Modified | 引入 UuidIdentity，新增 setter |
| `app/models/ticket.rb` | ✏️ 修改 Modified | 引入 UuidIdentity，简化 creator/assignee |
| `app/models/ticket_message.rb` | ✏️ 修改 Modified | 引入 UuidIdentity，简化 sender |
| `app/models/merchant_profile.rb` | ✏️ 修改 Modified | 引入 UuidIdentity，简化 admin 查找方法 |
| `app/models/merchant_review_log.rb` | ✏️ 修改 Modified | 引入 UuidIdentity，简化 operator |
| `app/models/audit_log.rb` | ✏️ 修改 Modified | 引入 UuidIdentity，优化 actor 分支逻辑 |
| `app/models/risk_event.rb` | ✏️ 修改 Modified | 引入 UuidIdentity，新增实例变量缓存 |
| `app/models/refund.rb` | ✏️ 修改 Modified | 引入 UuidIdentity，新增实例变量缓存 |
| `app/models/user.rb` | ✏️ 修改 Modified | 移除 JTIMatcher、:jwt_authenticatable 等；**修复 has_many 关联（Issue 1）**：customer_orders/merchant_orders 改为实例方法 |
| `app/services/orders/assign_merchant_service.rb` | ✏️ 修改 Modified | format_user_id_as_uuid 委托给 UuidIdentity |
| `app/services/bi/refund_analysis_service.rb` | ✏️ 修改 Modified | UUID 解码改用 Order.uuid_to_id |
| `app/services/fund_monitoring/frequent_refund_detector.rb` | ✏️ 修改 Modified | UUID 解码改用 Order.uuid_to_id |
| `config/initializers/devise.rb` | ✏️ 修改 Modified | 移除 JWT 配置块，保留注释说明 |
| `config/routes.rb` | ✏️ 修改 Modified | 移除 devise_scope sign_in/sign_out，devise_for :users 限为 passwords |
| `db/migrate/20260413000001_relax_user_devise_constraints.rb` | 🆕 新建 New | Migration：放宽约束，新增 Logto 字段 |
| `spec/models/concerns/uuid_identity_spec.rb` | 🆕 新建 New | UuidIdentity 34 个测试用例（含 customer_orders/merchant_orders 回归守卫）|

---

## 7. 验收清单 / Acceptance Checklist

测试人员请逐项确认，全部勾选后本次 Week 0 验收通过。  
Testers: check all items before declaring Week 0 acceptance complete.

### Day 0a — UuidIdentity Concern

- [ ] `app/models/concerns/uuid_identity.rb` 文件存在 / File exists
- [ ] `Order.id_to_uuid(42)` 返回 `"00000000-0000-0000-0000-000000000042"` ✓
- [ ] `Order.uuid_to_id("00000000-0000-0000-0000-000000000042")` 返回 `42` ✓
- [ ] `Order.id_to_uuid(nil)` 返回 `nil` ✓
- [ ] `Order.first.customer` 返回正确 User（TC-03）✓
- [ ] `Order.first.customer_user` 与 `Order.first.customer` 相同（别名）✓
- [ ] `Bid.first.bidder` 返回正确 User（TC-04）✓
- [ ] `Ticket.first.creator` 返回正确 User / AdminUser（TC-05）✓
- [ ] `MerchantProfile.first.approved_by_admin` 返回正确 AdminUser（TC-06）✓
- [ ] `grep -rn "split('-').last.to_i" app/models/` 返回 0 条结果（TC-11）✓
- [ ] `user.customer_orders.to_sql` 包含 UUID 格式（`'00000000-...'`），不含 bigint（TC-03b）✓
- [ ] `user.customer_orders.count` 返回非负整数，有订单时不为 0（TC-03b）✓
- [ ] `bundle exec rspec spec/models/concerns/uuid_identity_spec.rb` → **34 passed, 0 failures** ✓

### Day 0b — Migration + Devise 配置

- [ ] `bundle exec rails db:migrate` 执行无报错 ✓
- [ ] `users.encrypted_password` 列允许 NULL（TC-01）✓
- [ ] `users.external_id` 列存在，有唯一索引（TC-01）✓
- [ ] `users.auth_provider` 列存在，默认值 `"logto"`（TC-01）✓
- [ ] `users.locale` 列存在，默认值 `"zh-CN"`（TC-01）✓
- [ ] `users.country_code` 列存在（TC-01）✓
- [ ] `User.new(email: "x@test.com").valid?` 不报密码相关错误（TC-12）✓
- [ ] `User.ancestors.include?(Devise::JWT::RevocationStrategies::JTIMatcher)` = `false`（TC-12）✓
- [ ] AdminUser 可以正常登录 ActiveAdmin（TC-13）✓
- [ ] AdminUser 密码强度验证仍生效（TC-13）✓
- [ ] 订单列表显示 `customer_user&.email` 正常（TC-15）✓
- [ ] `POST /api/v1/users/sign_in` 返回 404（路由已移除，计划内）✓
- [ ] `GET /admin` 和 AdminUser 登录路由正常（TC-14）✓

---

## 8. 测试环境搭建 / Test Environment Setup

```bash
# 1. 确保依赖最新
bundle install

# 2. 执行迁移
bundle exec rails db:migrate

# 3. 运行核心自动化测试
bundle exec rspec spec/models/concerns/uuid_identity_spec.rb --format documentation

# 4. 运行全量回归
bundle exec rspec --format progress 2>&1 | tail -5

# 5. 手动启动服务器（用于 ActiveAdmin 测试）
bundle exec rails server -p 3000
# 访问 http://localhost:3000/admin
```

---

*文档生成时间 Generated：2026-04-13*  
*对应开发计划 Dev Plan：Logto2.md v2.1 Week 0*  
*由 Claude 根据实际代码实现自动生成 / Auto-generated by Claude based on actual implementation*
