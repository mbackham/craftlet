# Week 2 用户端核心 API — 单元测试文档

> 生成时间：2026-04-15  
> 测试结果：**53 examples, 0 failures**  
> 测试环境：Rails 7.1 / RSpec / Pagy 43 / FactoryBot

---

## 概览

| 测试文件 | 覆盖端点 | 用例数 | 通过 |
|----------|----------|--------|------|
| `spec/requests/api/v1/users/profiles_spec.rb` | GET/PATCH /api/v1/users/profile | 6 | ✅ 6 |
| `spec/requests/api/v1/users/device_tokens_spec.rb` | POST/DELETE /api/v1/users/device_tokens | 8 | ✅ 8 |
| `spec/requests/api/v1/orders_spec.rb` | GET/POST /api/v1/orders, POST cancel | 15 | ✅ 15 |
| `spec/requests/api/v1/payments_spec.rb` | POST /api/v1/payments, GET status | 9 | ✅ 9 |
| `spec/requests/api/v1/bids_spec.rb` | GET/POST /api/v1/orders/:id/bids | 7 | ✅ 7 |
| `spec/requests/api/v1/notifications_spec.rb` | GET /api/v1/notifications, PATCH mark_read | 8 | ✅ 8 |
| **合计** | | **53** | **53** |

---

## 认证策略

所有 Week 2 API 均需要 Logto JWT 认证。测试中通过 stub `Auth::JwtVerifier.call` 返回 `Auth::TokenClaims` 对象，绕过真实 JWKS 网络调用。

```ruby
# 测试中通用的 JWT Mock 模式
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
```

`rails_helper.rb` 全局配置：
- `Rack::Attack.enabled = false` — 禁用限流，避免测试触发 503
- `Rails.application.config.logto_configured = true` — 启用 JWT 中间件

---

## Day 6 — 用户资料 API

### 测试文件
`spec/requests/api/v1/users/profiles_spec.rb`  
`spec/requests/api/v1/users/device_tokens_spec.rb`

### GET /api/v1/users/profile

| 场景 | 预期状态码 | 验证点 |
|------|-----------|--------|
| 无认证头 | 401 | `success: false`, `code: "unauthorized"` |
| 有效 JWT | 200 | 返回 `id`, `email`, `nickname`（Logto sync 后）, `locale`, `status` |

> ⚠️ 注意：`UserSyncService.update_if_changed` 会将 nickname 同步为 Logto TokenClaims 中的 `name`，测试断言使用同步后的值 `'Test User'`。

### PATCH /api/v1/users/profile

| 场景 | 预期状态码 | 验证点 |
|------|-----------|--------|
| 无认证头 | 401 | 未授权 |
| 更新 locale & nickname | 200 | 响应和数据库均更新 |
| 更新 country_code | 200 | DB 值正确 |
| 传入不允许字段（status） | 200 | status 字段被忽略，保持原值 |

### POST /api/v1/users/device_tokens

| 场景 | 预期状态码 | 验证点 |
|------|-----------|--------|
| 无认证头 | 401 | — |
| 创建 iOS token | 201 | `token`, `platform: "ios"` 返回 |
| 幂等（重复 token） | 201 | `DeviceToken.count` 不变 |
| 非法平台（windows） | 422 | `success: false` |
| 缺少 token 字段 | 422 | 验证错误 |

### DELETE /api/v1/users/device_tokens/:id

| 场景 | 预期状态码 | 验证点 |
|------|-----------|--------|
| 无认证头 | 401 | — |
| 删除存在的 token | 204 | `DeviceToken.count` -1 |
| token 不存在 | 404 | `code: "not_found"` |

---

## Day 7 — 订单 CRUD API（消费者端）

### 测试文件
`spec/requests/api/v1/orders_spec.rb`

### GET /api/v1/orders

| 场景 | 预期状态码 | 验证点 |
|------|-----------|--------|
| 无认证头 | 401 | — |
| 查看订单列表 | 200 | 只返回当前用户作为 customer 的订单（非 merchant 的）|
| 分页 meta | 200 | 包含 `current_page`, `total_pages`, `total_count`, `per_page` |
| 排序验证 | 200 | 按 `created_at desc` 降序 |

### GET /api/v1/orders/:id

| 场景 | 预期状态码 | 验证点 |
|------|-----------|--------|
| 无认证头 | 401 | — |
| 查看自己的订单详情 | 200 | 含 `order_items`, `payments` 详情视图 |
| 查看他人订单 | 403 | `code: "forbidden"` |
| 订单不存在 | 404 | `code: "not_found"` |

### POST /api/v1/orders

| 场景 | 预期状态码 | 验证点 |
|------|-----------|--------|
| 无认证头 | 401 | — |
| 创建订单 | 201 | `Order.count` +1，`status: "created"`，`total_amount` 正确 |
| order_no 格式 | 201 | 匹配 `/\AORD\d{14}[A-F0-9]{6}\z/` |
| customer_id 验证 | 201 | `order.customer_id` = `Order.id_to_uuid(current_user.id)` |

### POST /api/v1/orders/:id/cancel

| 场景 | 预期状态码 | 验证点 |
|------|-----------|--------|
| 无认证头 | 401 | — |
| 取消 created 状态订单 | 200 | `status: "canceled"`，DB 更新 |
| 取消 completed 订单 | 422 | `code: "invalid_state"` |
| 取消他人订单 | 403 | `code: "forbidden"` |
| 订单不存在 | 404 | `code: "not_found"` |

---

## Day 8 — 支付创建 API

### 测试文件
`spec/requests/api/v1/payments_spec.rb`

### POST /api/v1/payments

| 场景 | 预期状态码 | 验证点 |
|------|-----------|--------|
| 无认证头 | 401 | — |
| 微信支付创建成功 | 201 | `Payment.count` +1，含 `channel`, `amount`, `status: "pending"`, `pay_params` |
| 不支持的渠道（bitcoin） | 422 | `code: "unsupported_channel"` |
| 非订单所属用户 | 403 | 不能为他人订单创建支付 |
| 订单非 created 状态 | 422 | `code: "invalid_order_status"` |

> Provider mock：使用 `allow_any_instance_of(Payments::WechatProvider).to receive(:create_payment)` 返回模拟支付数据。

### GET /api/v1/payments/:id/status

| 场景 | 预期状态码 | 验证点 |
|------|-----------|--------|
| 无认证头 | 401 | — |
| 查询自己订单的支付状态 | 200 | 含 `status: "paid"`, `channel`, `paid_at` |
| 查询他人订单的支付 | 403 | 权限验证 |
| 支付记录不存在 | 404 | `code: "not_found"` |

---

## Day 9 — 竞价 API + 通知列表 API

### 测试文件
`spec/requests/api/v1/bids_spec.rb`  
`spec/requests/api/v1/notifications_spec.rb`

### GET /api/v1/orders/:order_id/bids

| 场景 | 预期状态码 | 验证点 |
|------|-----------|--------|
| 无认证头 | 401 | — |
| 当前用户非 customer（是 bidder）| 403 | 只有订单的 customer 能查看报价列表 |
| customer 查看报价列表 | 200 | 返回全部报价 |

### POST /api/v1/orders/:order_id/bids

| 场景 | 预期状态码 | 验证点 |
|------|-----------|--------|
| 无认证头 | 401 | — |
| 提交有效报价 | 201 | `Bid.count` +1，`bidder_id = Bid.id_to_uuid(current_user.id)` |
| 订单不存在 | 404 | `code: "not_found"` |
| 金额为 0（无效） | 422 | 验证错误 |

### GET /api/v1/notifications

| 场景 | 预期状态码 | 验证点 |
|------|-----------|--------|
| 无认证头 | 401 | — |
| 列表分页 | 200 | 只返回当前用户的通知，含 `meta` 分页信息 |
| 排序 | 200 | 按 `created_at desc` 降序 |
| read 字段 | 200 | 已读/未读状态正确标记 |

### PATCH /api/v1/notifications/mark_read

| 场景 | 预期状态码 | 验证点 |
|------|-----------|--------|
| 无认证头 | 401 | — |
| 按 ids 批量标记 | 200 | 指定 ids 已读，其余不变，返回 `marked_count` |
| 不传 ids（全部已读）| 200 | 所有未读通知标记已读 |
| 不能标记他人通知 | 200 | 其他用户通知 `read?` 仍为 false |

---

## 已知限制与说明

### 遗留失败测试（非本期引入）
以下测试在本次开发前已失败，与 Week 2 无关：
- `spec/requests/api/v1/users/sessions_spec.rb` — Devise session 路由在 Week 0 已删除，该测试待更新
- `spec/models/fund_alert_spec.rb` — enum 类型配置问题（已有问题）
- `spec/services/fund_monitoring/daily_report_service_spec.rb` — 数据统计问题（已有问题）

### 测试环境特殊配置
| 配置项 | 说明 |
|--------|------|
| `Rack::Attack.enabled = false` | 防止限流器在快速测试中触发 503 |
| `logto_configured = true` | 让认证中间件进入 JWT 验证流程 |
| `Auth::JwtVerifier.call` stub | 跳过真实 JWKS 网络请求 |
| Provider mock | `WechatProvider#create_payment` mock 避免真实支付接口调用 |

### Pagy 43.x 兼容性
本期使用 Pagy 43.2.2（非旧版 Pagy::Backend 架构），已适配：
- `include Pagy::Method` 替代 `include Pagy::Backend`
- `pagy.last` 替代 `pagy.pages`（总页数）
- `pagy.limit` 替代 `pagy.items`（每页条数）

---

## 运行测试命令

```bash
# 运行所有 Week 2 测试
bundle exec rspec \
  spec/requests/api/v1/users/profiles_spec.rb \
  spec/requests/api/v1/users/device_tokens_spec.rb \
  spec/requests/api/v1/orders_spec.rb \
  spec/requests/api/v1/payments_spec.rb \
  spec/requests/api/v1/bids_spec.rb \
  spec/requests/api/v1/notifications_spec.rb \
  --format documentation

# 运行单个文件
bundle exec rspec spec/requests/api/v1/orders_spec.rb --format documentation

# 运行单个用例（使用行号）
bundle exec rspec spec/requests/api/v1/orders_spec.rb:137

# 验证已有测试不受影响
bundle exec rspec spec/requests/auth_flow_spec.rb spec/requests/api/v1/feedbacks_spec.rb
```

---

## 验收标准 Checklist

### Day 6 用户资料 API
- [x] `GET /api/v1/users/profile` 返回当前用户信息（含 locale、status）
- [x] `PATCH /api/v1/users/profile` 更新 locale/nickname/country_code 成功
- [x] `POST /api/v1/users/device_tokens` 注册推送 token（幂等）
- [x] `DELETE /api/v1/users/device_tokens/:id` 注销 token

### Day 7 订单 CRUD API
- [x] `GET /api/v1/orders` 返回分页订单列表（只返回自己的订单）
- [x] `GET /api/v1/orders/:id` 返回详情（含 order_items、payments）
- [x] `POST /api/v1/orders` 创建订单，customer_id 自动设置为当前用户
- [x] `POST /api/v1/orders/:id/cancel` 取消订单（状态机校验）
- [x] Pundit 权限：只能查看自己的订单（403 验证通过）

### Day 8 支付 API
- [x] `POST /api/v1/payments` 创建支付单，返回 pay_params
- [x] `GET /api/v1/payments/:id/status` 查询支付状态
- [x] 渠道校验（不支持的渠道返回 422）
- [x] 订单状态校验（非 created 状态返回 422）
- [x] 权限校验（非订单 customer 返回 403）

### Day 9 竞价 + 通知 API
- [x] `POST /api/v1/orders/:order_id/bids` 商家提交报价，bidder_id UUID 编码正确
- [x] `GET /api/v1/orders/:order_id/bids` 消费者查看报价（非 customer 返回 403）
- [x] `GET /api/v1/notifications` 返回分页通知（含 read 状态）
- [x] `PATCH /api/v1/notifications/mark_read` 批量已读（按 ids 或全部）
