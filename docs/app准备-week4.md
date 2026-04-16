# Craftlet Week 4 扩展功能 — 功能测试文档

> **版本**：Week 4 实现版  
> **更新日期**：2026-04-16  
> **测试环境**：`http://localhost:3000`（或联调环境地址）  
> **Swagger UI**：`http://localhost:3000/api-docs`  
> **认证方式**：所有标注 🔒 的接口需在请求头携带 `Authorization: Bearer <Logto JWT Token>`

---

## 目录

1. [前置准备](#前置准备)
2. [模块一：工单系统 API](#模块一工单系统-api)
3. [模块二：推送通知系统（后台服务）](#模块二推送通知系统后台服务)
4. [模块三：ActionCable 实时通信](#模块三actioncable-实时通信)
5. [模块四：i18n 国际化](#模块四i18n-国际化)
6. [模块五：安全限流（Rack::Attack）](#模块五安全限流rackattack)
7. [端到端完整场景测试](#端到端完整场景测试)
8. [异常场景汇总](#异常场景汇总)

---

## 前置准备

### 1. 获取测试 Token

```
Authorization: Bearer <your_logto_jwt_token>
```

### 2. 准备测试账号

| 角色 | 说明 |
|------|------|
| **普通用户 A** | 未创建过工单，用于测试创建流程 |
| **有工单用户 B** | 已有多条不同状态工单 |
| **用户 C（含设备 Token）** | 已注册 iOS/Android 推送 Token，验证推送接收 |
| **其他用户 D** | 验证数据隔离（不能访问别人的工单） |

### 3. 准备测试数据

通过 Rails console 创建：

```ruby
# 创建测试工单（状态：open）
user_b = User.find_by(email: 'user-b@example.com')
Ticket.create!(
  creator_id:   Ticket.id_to_uuid(user_b.id),
  creator_type: 'User',
  subject:      '测试工单 - 订单问题',
  description:  '我的订单 ORD20260416001 超过 5 天没有更新状态',
  category:     'order',
  priority:     'high',
  status:       'open'
)

# 创建已关闭工单
Ticket.create!(
  creator_id:   Ticket.id_to_uuid(user_b.id),
  creator_type: 'User',
  subject:      '已关闭工单',
  category:     'general',
  status:       'closed',
  closed_at:    Time.current
)

# 注册测试设备 Token
user_c = User.find_by(email: 'user-c@example.com')
DeviceToken.create!(user: user_c, token: 'ExponentPushToken[your-test-token]', platform: 'ios')
```

---

## 模块一：工单系统 API

### TC-T1-01 ✅ 获取工单列表

**接口**：`GET /api/v1/tickets` 🔒

**测试步骤**：使用用户 B 的 Token 发送请求

```
GET /api/v1/tickets
Authorization: Bearer <User_B_Token>
```

**预期结果**：

```json
HTTP 200 OK

{
  "success": true,
  "data": [
    {
      "id": <数字>,
      "ticket_no": "TK-20260416-XXXX",
      "subject": "测试工单 - 订单问题",
      "status": "open",
      "category": "order",
      "priority": "high",
      "created_at": "<ISO 8601>",
      "assigned_at": null,
      "resolved_at": null,
      "closed_at": null
    }
  ],
  "meta": {
    "current_page": 1,
    "total_pages": 1,
    "total_count": <数字>,
    "per_page": 20
  }
}
```

**验证点**：
- [ ] HTTP 状态码 200
- [ ] 只返回当前用户的工单（不含其他用户）
- [ ] 按 `created_at` 倒序排列
- [ ] 包含分页 `meta`
- [ ] `ticket_no` 格式为 `TK-YYYYMMDD-XXXX`

---

### TC-T1-02 ✅ 创建工单

**接口**：`POST /api/v1/tickets` 🔒

**测试步骤**：

```json
POST /api/v1/tickets
Authorization: Bearer <User_A_Token>
Content-Type: application/json

{
  "ticket": {
    "subject": "支付失败但订单已扣款",
    "description": "使用微信支付时提示失败，但银行卡已扣款 299 元，订单号 ORD20260416002",
    "category": "payment",
    "priority": "urgent"
  }
}
```

**预期结果**：

```json
HTTP 201 Created

{
  "success": true,
  "data": {
    "id": <数字>,
    "ticket_no": "TK-20260416-XXXX",
    "subject": "支付失败但订单已扣款",
    "status": "open",
    "category": "payment",
    "priority": "urgent",
    "created_at": "<ISO 8601>"
  }
}
```

**验证点**：
- [ ] HTTP 状态码 201
- [ ] `data.status` 为 `"open"`
- [ ] `data.ticket_no` 自动生成且唯一
- [ ] 数据库中可见新工单，`creator_id` 为当前用户
- [ ] 站内通知已创建（查询 `user_a.notifications` 可见「工单已提交」通知）
- [ ] Sidekiq 队列中有 `TicketNotificationJob` 任务

---

### TC-T1-03 ❌ 创建工单 — subject 为空

**测试步骤**：发送 `subject: ""` 的请求

**预期结果**：

```json
HTTP 422 Unprocessable Entity

{
  "success": false,
  "error": {
    "code": "validation_error",
    "message": "Subject can't be blank"
  }
}
```

**验证点**：
- [ ] HTTP 422
- [ ] `error.code` 为 `"validation_error"`

---

### TC-T1-04 ❌ 创建工单 — 无效 category

**测试步骤**：发送 `category: "invalid_type"`

**预期结果**：HTTP 422，`error.code = "validation_error"`

---

### TC-T1-05 ✅ 查看工单详情

**接口**：`GET /api/v1/tickets/:id` 🔒

**前提**：用户 B 有一个 open 状态工单，记录其 `id`

**预期结果**：

```json
HTTP 200 OK

{
  "success": true,
  "data": {
    "id": <数字>,
    "ticket_no": "TK-...",
    "subject": "测试工单 - 订单问题",
    "description": "我的订单...",
    "status": "open",
    "category": "order",
    "priority": "high",
    "messages": [],
    "created_at": "<ISO 8601>",
    "assigned_at": null,
    "resolved_at": null,
    "closed_at": null
  }
}
```

**验证点**：
- [ ] 包含 `description` 字段（列表接口无此字段）
- [ ] 包含 `messages` 数组（空或有消息内容）
- [ ] `messages` 只包含非内部消息（`internal: false`）

---

### TC-T1-06 ❌ 查看他人工单被拒绝

**前提**：用户 A 尝试访问用户 D 的工单 ID

**预期结果**：HTTP 404 Not Found

---

### TC-T1-07 ✅ 追加工单消息

**接口**：`POST /api/v1/tickets/:id/messages` 🔒

**前提**：用户 B 有一个 `status = "open"` 的工单

**测试步骤**：

```json
POST /api/v1/tickets/{工单ID}/messages
Authorization: Bearer <User_B_Token>
Content-Type: application/json

{
  "message": {
    "content": "请问处理进度如何？我的问题还没有解决"
  }
}
```

**预期结果**：

```json
HTTP 201 Created

{
  "success": true,
  "data": {
    "id": <数字>,
    "content": "请问处理进度如何？我的问题还没有解决",
    "sender_type": "User",
    "internal": false,
    "created_at": "<ISO 8601>"
  }
}
```

**验证点**：
- [ ] HTTP 201
- [ ] `sender_type` 为 `"User"`
- [ ] `internal` 为 `false`（用户消息不是内部备注）
- [ ] 工单详情中 `messages` 可见新消息

---

### TC-T1-08 ❌ 向已关闭工单追加消息

**前提**：用户 B 有一个 `status = "closed"` 的工单

**预期结果**：

```json
HTTP 422 Unprocessable Entity

{
  "success": false,
  "error": {
    "code": "ticket_closed",
    "message": "工单已关闭，无法追加消息"
  }
}
```

---

### TC-T1-09 ✅ 关闭工单

**接口**：`PATCH /api/v1/tickets/:id/close` 🔒

**前提**：用户 B 有一个 `status = "open"` 的工单

**测试步骤**：

```
PATCH /api/v1/tickets/{工单ID}/close
Authorization: Bearer <User_B_Token>
```

**预期结果**：

```json
HTTP 200 OK

{
  "success": true,
  "data": {
    "id": <数字>,
    "ticket_no": "TK-...",
    "status": "closed",
    "closed_at": "<ISO 8601>"
  }
}
```

**验证点**：
- [ ] `data.status` 为 `"closed"`
- [ ] `data.closed_at` 有时间值
- [ ] 数据库中状态已更新

---

### TC-T1-10 ❌ 重复关闭工单

**前提**：工单状态已为 `"closed"`

**预期结果**：

```json
HTTP 422 Unprocessable Entity

{
  "success": false,
  "error": {
    "code": "invalid_state",
    "message": "当前工单状态不允许关闭"
  }
}
```

---

### TC-T1-11 ❌ 未携带 Token

**测试步骤**：不带 `Authorization` 头访问任意工单接口

**预期结果**：HTTP 401 Unauthorized

---

## 模块二：推送通知系统（后台服务）

> ⚠️ **说明**：推送通知不通过 API 接口直接测试，而是通过触发订单状态流转间接验证。

### TC-PUSH-01 ✅ 设备 Token 注册

**接口**：`POST /api/v1/users/device_tokens` 🔒

**测试步骤**：

```json
POST /api/v1/users/device_tokens
Authorization: Bearer <User_C_Token>
Content-Type: application/json

{
  "device_token": {
    "token": "ExponentPushToken[your-expo-token]",
    "platform": "ios"
  }
}
```

**预期结果**：HTTP 201，DeviceToken 记录已创建

---

### TC-PUSH-02 ✅ 订单状态变更触发推送（集成验证）

**前提**：
- 用户 C 已注册有效 Expo Push Token
- 已审核商家接受用户 C 的订单

**验证方式**：
1. 商家调用 `POST /api/v1/merchant/orders/:id/accept`
2. 检查 Sidekiq 队列中是否有 `Notifications::OrderStatusNotificationJob`（event: `accepted`）
3. 检查用户 C 的 `notifications` 表中是否新增「订单已接受」通知

**通过 Rails console 验证**：

```ruby
# 查看待处理 Job
Sidekiq::Queue.all.each { |q| puts q.name, q.size }

# 查看站内通知
user_c.notifications.last
# => #<Notification title="订单已接受" notification_type="order_accepted" ...>
```

---

### TC-PUSH-03 ✅ 工单创建触发通知

**前提**：用户 A 创建工单后

**验证方式**：
```ruby
# 查看站内通知
user_a.notifications.where(notification_type: 'ticket_created').last
# => #<Notification title="工单已提交" ...>
```

---

## 模块三：ActionCable 实时通信

> ⚠️ **说明**：ActionCable 需要在 WebSocket 客户端（如 JavaScript 控制台或专用工具）中测试。

### TC-WS-01 ✅ JWT 认证连接

**连接方式**（浏览器控制台）：

```javascript
// 需要先引入 @rails/actioncable
import { createConsumer } from "@rails/actioncable"

// 带 JWT Token 的 WebSocket 连接
const consumer = createConsumer(`ws://localhost:3000/cable?token=${accessToken}`)
```

**验证点**：
- [ ] 有效 Token 连接成功（服务端日志出现 `Connection#subscribe` 记录）
- [ ] 无 Token 连接被拒绝（`reject_unauthorized_connection`）
- [ ] 无效 Token 连接被拒绝

---

### TC-WS-02 ✅ 订阅订单状态 Channel

**JavaScript 示例**：

```javascript
const subscription = consumer.subscriptions.create(
  { channel: 'OrderStatusChannel', order_id: 123 },
  {
    connected()    { console.log('已连接订单状态频道') },
    disconnected() { console.log('已断开') },
    received(data) { console.log('收到状态更新:', data) }
  }
)
```

**触发更新**（后端调用商家接单接口后）：
```json
// 收到的推送数据格式
{
  "order_id": 123,
  "status": "accepted",
  "event": "accepted",
  "updated_at": "2026-04-16T10:00:00+08:00"
}
```

**验证点**：
- [ ] 消费者（订单创建者）可以成功订阅
- [ ] 商家（订单处理者）可以成功订阅
- [ ] 无关用户订阅被拒绝（`rejected`）
- [ ] 订单状态变更时实时收到推送

---

### TC-WS-03 ✅ 订阅个人通知 Channel

**JavaScript 示例**：

```javascript
const notifSubscription = consumer.subscriptions.create(
  { channel: 'NotificationsChannel' },
  {
    received(data) { console.log('新通知:', data) }
  }
)
```

**验证点**：
- [ ] 每个用户只能订阅自己的通知流
- [ ] 后台创建站内通知后，客户端实时收到（可通过 `NotificationsChannel.broadcast_to(user, data)` 触发）

---

## 模块四：i18n 国际化

### TC-I18N-01 ✅ 中文错误消息（默认）

**测试步骤**：发送无 Token 请求

```
GET /api/v1/tickets
（不携带 Authorization 头）
```

**预期结果**：

```json
HTTP 401

{
  "success": false,
  "error": {
    "code": "unauthorized",
    "message": "请先登录"
  }
}
```

---

### TC-I18N-02 ✅ 英文错误消息

**测试步骤**：带 `Accept-Language: en` 请求头访问

```
GET /api/v1/tickets
Accept-Language: en
（不携带 Authorization 头）
```

**预期结果**：

```json
HTTP 401

{
  "success": false,
  "error": {
    "code": "unauthorized",
    "message": "Please sign in to continue"
  }
}
```

**验证点**：
- [ ] 中文用户（无 Accept-Language 或 `zh-CN`）收到中文消息
- [ ] 英文用户（`Accept-Language: en`）收到英文消息

---

### TC-I18N-03 ✅ 工单状态/分类国际化文本

**说明**：工单的 `status`、`category`、`priority` 字段返回的是原始枚举值（如 `"open"`、`"order"`），国际化文本通过 `locale` 文件提供，供前端 i18n 库使用。

**locale 路径**：
- 中文：`config/locales/api.zh-CN.yml` → `api.tickets.status.open = "待处理"`
- 英文：`config/locales/api.en.yml` → `api.tickets.status.open = "Open"`

---

## 模块五：安全限流（Rack::Attack）

> ⚠️ **说明**：限流测试需要在非 development 环境（使用 MemoryStore）进行，并且需要快速发送大量请求。推荐使用压测工具（如 `wrk` 或 `ab`）。

### TC-RL-01 ✅ 工单创建限流（10次/小时/IP）

**测试步骤**：同一 IP 在 1 小时内发送 11 次 `POST /api/v1/tickets`

**预期结果**（第 11 次）：

```json
HTTP 429 Too Many Requests

{
  "success": false,
  "error": {
    "code": "rate_limited",
    "message": "请求过于频繁，请稍后再试 / Too many requests, please try again later",
    "retry_after": 3600
  }
}
```

**验证点**：
- [ ] HTTP 429
- [ ] `Retry-After` 响应头存在
- [ ] `error.code` 为 `"rate_limited"`

---

### TC-RL-02 ✅ 支付创建限流（5次/分钟/Token）

**测试步骤**：同一 Bearer Token 在 1 分钟内发送 6 次 `POST /api/v1/payments`

**预期结果**（第 6 次）：HTTP 429

---

### TC-RL-03 ✅ 全局 IP 限流（300次/分钟/IP）

**测试步骤**：同一 IP 在 1 分钟内发送 301 次请求

**预期结果**（第 301 次）：HTTP 429

---

### TC-RL-04 ✅ 限流不影响健康检查

**测试步骤**：高并发时访问 `GET /up`

**预期结果**：始终返回 HTTP 200（健康检查被排除在全局限流之外）

---

## 端到端完整场景测试

### E2E-01：用户提交工单 → 客服处理 → 用户关闭

| 步骤 | 操作 | 期望结果 |
|------|------|---------|
| 1 | 用户 A 调用 `POST /api/v1/tickets`，提交支付问题工单 | 201，status=open，ticket_no 自动生成 |
| 2 | 用户 A 调用 `GET /api/v1/tickets` | 见到新工单，status=open |
| 3 | 用户 A 调用 `GET /api/v1/tickets/:id` | 见工单详情，messages 为空 |
| 4 | 管理员在 ActiveAdmin 中分配工单给客服 | 工单 status=assigned |
| 5 | 用户 A 调用 `GET /api/v1/tickets/:id` | status=assigned，assigned_at 有值 |
| 6 | 客服在 ActiveAdmin 中回复工单消息 | TicketMessage 创建，internal=false |
| 7 | 用户 A 调用 `GET /api/v1/tickets/:id` | messages 中可见客服回复 |
| 8 | 用户 A 调用 `POST /api/v1/tickets/:id/messages`，追加消息 | 201，用户消息已添加 |
| 9 | 管理员在 ActiveAdmin 中标记工单解决 | status=resolved |
| 10 | 用户 A 调用 `PATCH /api/v1/tickets/:id/close` | 200，status=closed |

---

### E2E-02：订单完整流程 + 推送通知验证

| 步骤 | 操作 | 期望结果 |
|------|------|---------|
| 1 | 用户 C 注册设备 Token | DeviceToken 记录创建 |
| 2 | 用户 C 创建订单并支付（status=paid） | Order 状态为 paid |
| 3 | 商家调用 `POST /api/v1/merchant/orders/:id/accept` | Order status=accepted |
| 4 | 检查 Sidekiq 队列 | `OrderStatusNotificationJob` 已入队（event=accepted） |
| 5 | Job 执行完成 | 用户 C 收到「订单已接受」推送通知（Expo 控制台可见） |
| 6 | 检查站内通知 | `user_c.notifications.last.notification_type == 'order_accepted'` |
| 7 | 商家调用 `start_producing` → `deliver` | 用户 C 依次收到制作中、发货通知 |

---

## 异常场景汇总

| 场景 | 接口 | 预期状态码 | error.code |
|------|------|-----------|------------|
| 无 Token | 所有 🔒 接口 | 401 | `unauthorized` |
| Token 无效/过期 | 所有 🔒 接口 | 401 | `unauthorized` |
| subject 为空 | POST /tickets | 422 | `validation_error` |
| 无效 category | POST /tickets | 422 | `validation_error` |
| 查看他人工单 | GET /tickets/:id | 404 | — |
| 向他人工单追加消息 | POST /tickets/:id/messages | 404 | — |
| 向关闭工单追加消息 | POST /tickets/:id/messages | 422 | `ticket_closed` |
| 消息内容为空 | POST /tickets/:id/messages | 422 | `validation_error` |
| 关闭他人工单 | PATCH /tickets/:id/close | 404 | — |
| 重复关闭工单 | PATCH /tickets/:id/close | 422 | `invalid_state` |
| 工单创建超限（10次/小时） | POST /tickets | 429 | `rate_limited` |
| 支付创建超限（5次/分钟） | POST /payments | 429 | `rate_limited` |
| API 全局超限（300次/分钟） | 任意 API | 429 | `rate_limited` |
| WebSocket 无 Token 连接 | WS /cable | 拒绝连接 | — |
| WebSocket 订阅他人订单 | OrderStatusChannel | rejected | — |

---

## 注意事项

### 1. 工单状态流转（用户视角）

用户只能执行一个操作：**关闭工单**（`PATCH /tickets/:id/close`）。

其他状态流转（分配、开始处理、解决）由客服/管理员在 ActiveAdmin 中操作：

```
open → assigned → in_progress → resolved → closed
         ↑—————————————————————————————— reopen ——↑
```

可关闭状态：`open`、`assigned`、`in_progress`、`resolved`

### 2. 工单消息可见性

- 用户只能看到 `internal: false` 的消息（`public_messages` scope）
- 客服内部备注（`internal: true`）对用户不可见
- 用户发送的消息自动设置 `internal: false`

### 3. 推送通知异步机制

推送通知通过 Sidekiq 异步执行：
- 触发业务操作（如接单）
- `OrderStatusNotificationJob` 入队 `:notifications` 队列
- Job 内部调用 `SendPushNotificationJob`（再次异步）发送 Expo 推送
- 同时写入数据库（站内通知）和 ActionCable 广播

**在测试环境中验证**：
```bash
# 确认 Sidekiq 正在运行
bundle exec sidekiq -q notifications,default

# 或使用 ActiveJob 测试模式（inline 执行）
# config/environments/test.rb
config.active_job.queue_adapter = :inline
```

### 4. ActionCable 与前端集成

WebSocket 连接 URL 格式：
```
ws://localhost:3000/cable?token=<logto_jwt_token>
```

生产环境使用 Redis adapter（`config/cable.yml` 已配置）。

### 5. Rack::Attack 测试环境

在 test/development 环境中，Rack::Attack 使用 `MemoryStore`（进程内缓存），每次重启服务后计数器重置。如需测试限流：
- 不重启服务器
- 快速发送足够次数的请求
- 或修改 `limit` 为较小值临时测试

### 6. 新增 Swagger 端点列表

Week 4 新增 4 个 Swagger 文档路径：
```
/api/v1/tickets           GET（列表）、POST（创建）
/api/v1/tickets/{id}      GET（详情）
/api/v1/tickets/{id}/messages  POST（追加消息）
/api/v1/tickets/{id}/close     PATCH（关闭）
```

访问 `http://localhost:3000/api-docs`，选择 **工单** 标签页查看完整文档。
