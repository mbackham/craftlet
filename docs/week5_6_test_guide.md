# Craftlet API 联调测试指导手册

> **适用阶段**：Week 5-6 前后端联调
> **文档版本**：v1.0（2026-04-16）
> **后端环境**：`http://localhost:3000` / 生产 `https://api.craftlet.com`
> **Swagger UI**：`/api-docs`

---

## 一、环境准备 & 工具

### 1.1 必须准备

| 工具 | 用途 | 下载 |
|------|------|------|
| Postman / Bruno | API 测试 | postman.com |
| Logto Tenant | 获取真实 JWT | logto.app |
| Redis（本地） | 确认推送/缓存正常 | - |

### 1.2 获取测试 Token

```bash
# 方式一：通过 Logto Console → API Resources → 测试 Tab 获取 Access Token
# 方式二：通过 SDK 登录流程获取（推荐，可测试完整登录链路）

# Token 格式（用于所有需要认证的 API）：
Authorization: Bearer <your_logto_access_token>
```

### 1.3 Base Headers

```
Content-Type: application/json
Accept: application/json
Authorization: Bearer <token>       # 除公开接口外必须携带
Accept-Language: zh-CN              # 可选，影响错误消息语言
```

---

## 二、认证流程联调

> **后端状态**：✅ 已完成
> **对应文件**：`app/services/auth/`，`app/channels/application_cable/connection.rb`

### TC-AUTH-001：首次登录自动注册

| 步骤 | 操作 | 预期结果 |
|------|------|----------|
| 1 | 在 Logto 使用微信/Apple 登录，获取 Access Token | Token 签发成功 |
| 2 | 用该 Token 请求 `GET /api/v1/users/profile` | HTTP 200，User 记录自动创建 |
| 3 | 第二次请求同一接口 | HTTP 200，不重复创建（幂等） |

```bash
curl -H "Authorization: Bearer <token>" \
     http://localhost:3000/api/v1/users/profile
```

**预期响应**：
```json
{
  "success": true,
  "data": {
    "id": 1,
    "email": "user@example.com",
    "locale": "zh-CN",
    "country_code": "CN"
  }
}
```

### TC-AUTH-002：Token 缺失/无效

```bash
# 无 Token
curl http://localhost:3000/api/v1/orders
# 预期：HTTP 401 {"success": false, "error": {"message": "..."}}

# 无效 Token
curl -H "Authorization: Bearer invalid.token" \
     http://localhost:3000/api/v1/orders
# 预期：HTTP 401
```

### TC-AUTH-003：公开接口无需认证

```bash
curl http://localhost:3000/api/v1/banners
curl http://localhost:3000/api/v1/announcements
curl http://localhost:3000/api/v1/faqs
# 预期：HTTP 200，无需 Authorization 头
```

### TC-AUTH-004：Token 过期后刷新

| 步骤 | 操作 | 预期结果 |
|------|------|----------|
| 1 | 使用过期 Token 请求任意认证接口 | HTTP 401 |
| 2 | 前端调用 Logto SDK `refreshToken()` | 获取新 Token |
| 3 | 用新 Token 重试请求 | HTTP 200 |

---

## 三、用户端 API 联调

> **后端状态**：✅ 全部完成

### TC-USER-001：获取/更新用户资料

```bash
# 获取资料
GET /api/v1/users/profile
# Authorization 必须

# 更新资料
PATCH /api/v1/users/profile
Content-Type: application/json
{"user": {"locale": "en", "country_code": "INTL"}}
# 预期：HTTP 200，locale/country_code 已更新
```

### TC-USER-002：注册推送设备 Token

```bash
POST /api/v1/users/device_tokens
{"device_token": {"token": "ExponentPushToken[xxxx]", "platform": "ios"}}
# 预期：HTTP 201

DELETE /api/v1/users/device_tokens/:id
# 预期：HTTP 204（登出时调用）
```

---

## 四、订单流程联调（消费者端）

> **后端状态**：✅ 全部完成
> **状态机**：`created → paid → accepted → producing → delivered → completed`
>             `created/paid → canceled`

### TC-ORDER-001：创建订单

```bash
POST /api/v1/orders
{
  "order": {
    "merchant_id": "00000000-0000-0000-0000-000000000001",
    "total_amount": "299.00",
    "currency": "CNY"
  }
}
```

**预期**：HTTP 201，`status: "created"`，`order_no` 格式为 `ORD{14位时间戳}{6位HEX}`

> ⚠️ **前端注意**：`merchant_id` 必须是 UUID 格式（`00000000-0000-0000-0000-{12位商家bigint ID}`）

### TC-ORDER-002：查看订单列表

```bash
GET /api/v1/orders?page=1
```

**预期响应格式**：
```json
{
  "success": true,
  "data": [...],
  "meta": {
    "current_page": 1,
    "total_pages": 3,
    "total_count": 25,
    "per_page": 10
  }
}
```

### TC-ORDER-003：取消订单

```bash
POST /api/v1/orders/:id/cancel
# 前提：订单状态为 created（未付款）
# 预期：HTTP 200，status: "canceled"

# 已完成订单取消（应失败）
POST /api/v1/orders/:id/cancel（状态为 completed）
# 预期：HTTP 422，code: "invalid_state"

# 取消他人订单（应失败）
# 预期：HTTP 403
```

### TC-ORDER-004：实时状态推送（WebSocket）

```javascript
// 前端连接方式
const ws = new WebSocket(
  `wss://api.craftlet.com/cable?token=${accessToken}`
);

// 订阅订单状态频道
const subscription = consumer.subscriptions.create(
  { channel: 'OrderStatusChannel', order_id: 123 },
  {
    received: (data) => {
      console.log('Order status updated:', data.status);
      // data = { order_id: 123, status: 'accepted', updated_at: '...' }
    }
  }
);
```

**测试步骤**：
1. 前端建立 WebSocket 连接（携带 token）
2. 订阅 `OrderStatusChannel`，传入 `order_id`
3. 后端（管理后台）修改订单状态
4. **预期**：前端实时收到状态变更推送

> ⚠️ **P0 Bug 已修复**：此前 WebSocket 权限验证存在对象比较 Bug，所有合法用户均被拒绝。现已修复。

---

## 五、支付流程联调

> **后端状态**：✅ API 框架完成，支付 SDK 参数需接入真实 key

### TC-PAY-001：创建支付单

```bash
POST /api/v1/payments
{
  "order_id": 123,
  "channel": "wechat"   # or "alipay"
}
```

**预期响应**（微信）：
```json
{
  "success": true,
  "data": {
    "payment_id": 456,
    "channel": "wechat",
    "params": {
      "prepay_id": "...",
      "timeStamp": "...",
      "nonceStr": "...",
      "package": "...",
      "signType": "RSA",
      "paySign": "..."
    }
  }
}
```

前端拿到 `params` 后调起微信/支付宝 SDK 完成支付。

### TC-PAY-002：查询支付状态

```bash
GET /api/v1/payments/:id/status
# 预期：{"status": "pending"} 或 {"status": "paid", "paid_at": "..."}
```

### TC-PAY-003：支付回调（后端接收）

| 渠道 | 回调地址 | 格式 |
|------|---------|------|
| 微信 | `POST /api/payments/callbacks/wechat` | XML |
| 支付宝 | `POST /api/payments/callbacks/alipay` | Form |

> ⚠️ **前端无需直接测试此接口**，由支付平台服务器自动调用。
> 联调时可用支付平台沙盒环境触发回调，观察订单状态自动变更。

---

## 六、商家端 API 联调

> **后端状态**：✅ 全部完成

### TC-MERCHANT-001：商家入驻申请

```bash
# 查看审核状态
GET /api/v1/merchant/status
# 预期：{"status": "not_applied"} 或 {"status": "pending_review"} 等

# 提交入驻申请
POST /api/v1/merchant/apply
{
  "merchant": {
    "business_name": "XX服务商",
    "contact_phone": "13800138000",
    "address_province": "广东省",
    "address_city": "深圳市"
  }
}
# 预期：HTTP 201
```

### TC-MERCHANT-002：商家订单管理完整流程

```bash
# Step 1: 查看待接订单
GET /api/v1/merchant/orders?status=paid
# 预期：只看到自己的订单，他人订单不可见

# Step 2: 接单（paid → accepted）
POST /api/v1/merchant/orders/:id/accept
# 预期：HTTP 200，status: "accepted"
# 副作用：消费者收到推送通知

# Step 3: 开始制作（accepted → producing）
POST /api/v1/merchant/orders/:id/start_producing
# 预期：HTTP 200，status: "producing"

# Step 4: 发货/完成（producing → delivered）
POST /api/v1/merchant/orders/:id/deliver
# 预期：HTTP 200，status: "delivered"
```

**状态流转错误测试**：
```bash
# 在 created 状态接单（应失败）
POST /api/v1/merchant/orders/:id/accept（状态为 created）
# 预期：HTTP 422，code: "invalid_state"

# 未审批商家访问（应被拒）
# 预期：HTTP 403，code: "merchant_not_approved"
```

### TC-MERCHANT-003：商家看板

```bash
GET /api/v1/merchant/dashboard
# 预期：
{
  "today_orders": 5,
  "pending_orders": 3,
  "this_month_revenue": "12500.00",
  "total_orders": 150,
  "rating": 4.8
}
```

### TC-MERCHANT-004：结算查询

```bash
GET /api/v1/merchant/settlements
GET /api/v1/merchant/settlements/:id
# 预期：结算记录列表，含金额、周期、状态
```

---

## 七、通知系统联调

> **后端状态**：✅ 完成

### TC-NOTIFY-001：站内通知

```bash
GET /api/v1/notifications?page=1
# 预期：通知列表，包含 title/body/read_at

PATCH /api/v1/notifications/mark_read
{"ids": [1, 2, 3]}
# 预期：HTTP 200，指定通知标记为已读
```

### TC-NOTIFY-002：Push 通知验证

1. 注册设备 Token（TC-USER-002）
2. 触发订单状态变更（商家接单）
3. **预期**：App 收到 Expo Push 通知

> ⚠️ **前提**：`.env` 中 `EXPO_ACCESS_TOKEN` 已配置

---

## 八、工单系统联调

> **后端状态**：✅ 完成

```bash
# 创建工单
POST /api/v1/tickets
{"ticket": {"subject": "订单问题", "category": "general", "priority": "normal"}}
# 预期：HTTP 201

# 查看工单列表
GET /api/v1/tickets

# 发送工单消息
POST /api/v1/tickets/:id/messages
{"content": "请问我的订单什么时候发货？"}

# 查看对话
GET /api/v1/tickets/:id/messages

# 用户关闭工单
PATCH /api/v1/tickets/:id/close
```

---

## 九、Rate Limiting 验证

> **后端状态**：✅ 已配置，生产环境已修复 Redis 配置

```bash
# 测试支付接口限流（同一 token 1分钟内最多5次）
for i in {1..6}; do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -X POST http://localhost:3000/api/v1/payments \
    -H "Authorization: Bearer <token>" \
    -H "Content-Type: application/json" \
    -d '{"order_id": 1, "channel": "wechat"}'
done
# 预期：前5次 200/422，第6次 429
# 响应头：Retry-After: 60
```

---

## 十、错误码速查表

| HTTP 状态码 | code 字段 | 含义 |
|------------|-----------|------|
| 401 | `unauthorized` | 未登录/Token 无效 |
| 403 | `forbidden` | 权限不足 |
| 403 | `merchant_not_approved` | 商家未审批 |
| 404 | `not_found` | 资源不存在 |
| 422 | `invalid_state` | 状态机流转非法 |
| 422 | `validation_failed` | 参数验证失败 |
| 429 | `rate_limited` | 请求过于频繁 |
| 500 | `internal_error` | 服务端错误（应上报 Sentry）|

---

## 十一、联调 Checklist

### 认证流程
- [ ] Logto 登录 → 获取 Access Token → 请求 API → 自动创建本地用户
- [ ] Token 过期 → App 端刷新 → 继续请求
- [ ] 微信登录（国内用户）完整流程
- [ ] Apple 登录（海外用户）完整流程

### 用户端流程
- [ ] 查看/编辑个人资料（locale/country_code）
- [ ] 注册/注销推送 Token
- [ ] 创建订单 → 选择支付方式 → 调起支付 → 支付成功
- [ ] 查看订单列表（分页）→ 订单详情 → 取消订单
- [ ] 接收推送通知（订单状态变更）
- [ ] WebSocket 实时状态更新（TC-ORDER-004）
- [ ] 查看/标记已读站内通知
- [ ] 提交/查看工单

### 商家端流程
- [ ] 商家入驻申请 → 提交资料 → 等待审核
- [ ] 审核通过通知 → 进入商家端
- [ ] 查看待接订单列表（按状态过滤）
- [ ] 接单 → 开始制作 → 发货（完整状态机）
- [ ] 未审批商家被正确拦截（403）
- [ ] 查看结算记录
- [ ] 商家看板数据展示

### 安全校验
- [ ] 消费者无法访问他人订单（403）
- [ ] 商家无法访问他人订单（404）
- [ ] Rate Limiting 超限返回 429
- [ ] WebSocket 无法订阅他人订单（rejected）

---

*本文档基于代码审计结果生成，如有接口变更请同步更新。*















📊 前端需要做的事（按优先级）                                                                                                                                                                                                                                             

  🔴 P0 必须（联调前）
                                                                                                                                                                                                                                                                            
  ┌─────┬──────────────────────────────┬──────────────────────────────────────────────────┐                                                                                                                                                                                 
  │  #  │           前端工作           │                       说明                       │                                                                                                                                                                                 
  ├─────┼──────────────────────────────┼──────────────────────────────────────────────────┤                                                                                                                                                                                 
  │ 1   │ Logto SDK 集成               │ 接入微信登录/Apple 登录，获取 Access Token       │
  ├─────┼──────────────────────────────┼──────────────────────────────────────────────────┤                                                                                                                                                                                 
  │ 2   │ Token 自动刷新               │ Token 过期（401）时自动调用 refreshToken() 重试  │                                                                                                                                                                                 
  ├─────┼──────────────────────────────┼──────────────────────────────────────────────────┤                                                                                                                                                                                 
  │ 3   │ WebSocket 连接（Token 携带） │ wss://api.craftlet.com/cable?token=<accessToken> │                                                                                                                                                                                 
  ├─────┼──────────────────────────────┼──────────────────────────────────────────────────┤                                                                                                                                                                                 
  │ 4   │ OrderStatusChannel 订阅      │ 订阅 {channel: 'OrderStatusChannel', order_id}   │
  └─────┴──────────────────────────────┴──────────────────────────────────────────────────┘                                                                                                                                                                                   
  🟡 P1 核心功能                                                                                                                                                                                                                                                              
  ┌─────┬─────────────────────────────────────┬────────────────────────────────────────┐
  │  #  │              前端工作               │                后端接口                │
  ├─────┼─────────────────────────────────────┼────────────────────────────────────────┤
  │ 5   │ 注册推送设备 Token                  │ POST /api/v1/users/device_tokens       │
  ├─────┼─────────────────────────────────────┼────────────────────────────────────────┤
  │ 6   │ 创建订单（merchant_id 格式为 UUID） │ POST /api/v1/orders                    │                                                                                                                                                                                    
  ├─────┼─────────────────────────────────────┼────────────────────────────────────────┤                                                                                                                                                                                    
  │ 7   │ 微信/支付宝 SDK 调起支付            │ 用 POST /api/v1/payments 返回的 params │                                                                                                                                                                                    
  ├─────┼─────────────────────────────────────┼────────────────────────────────────────┤                                                                                                                                                                                    
  │ 8   │ 商家端：接单/开始制作/发货三步操作  │ accept/start_producing/deliver         │
  ├─────┼─────────────────────────────────────┼────────────────────────────────────────┤                                                                                                                                                                                    
  │ 9   │ 未审批商家被 403 时的引导 UI        │ code: "merchant_not_approved"          │
  ├─────┼─────────────────────────────────────┼────────────────────────────────────────┤                                                                                                                                                                                    
  │ 10  │ 订单状态变更实时刷新（WebSocket）   │ OrderStatusChannel                     │
  └─────┴─────────────────────────────────────┴────────────────────────────────────────┘                                                                                                                                                                                      
  🟢 P2 可延后                                                                                                                                                                                                                                                                
  ┌─────┬──────────────────────────────────┬──────────────────────────────────┐                                                                                                                                                                                             
  │  #  │             前端工作             │               说明               │
  ├─────┼──────────────────────────────────┼──────────────────────────────────┤                                                                                                                                                                                             
  │ 11  │ 通知中心 UI（站内通知列表/已读） │ GET/PATCH /api/v1/notifications  │
  ├─────┼──────────────────────────────────┼──────────────────────────────────┤
  │ 12  │ 工单创建/回复界面                │ POST /api/v1/tickets             │                                                                                                                                                                                             
  ├─────┼──────────────────────────────────┼──────────────────────────────────┤                                                                                                                                                                                             
  │ 13  │ 商家看板数据展示                 │ GET /api/v1/merchant/dashboard   │                                                                                                                                                                                             
  ├─────┼──────────────────────────────────┼──────────────────────────────────┤                                                                                                                                                                                             
  │ 14  │ 结算记录列表                     │ GET /api/v1/merchant/settlements │
  ├─────┼──────────────────────────────────┼──────────────────────────────────┤                                                                                                                                                                                             
  │ 15  │ i18n 切换（按用户 locale）       │ 在 Profile 更新接口写入 locale   │
  └─────┴──────────────────────────────────┴──────────────────────────────────┘                                                                                                                                                                                               
  ---                                                                                                                                                                                                                                                                       
  ❌ 本期未实现 / 需后续排期
                                                                                                                                                                                                                                                                            
  ┌──────────────────────────────┬──────────────────────────┬───────────────────────────────┐
  │             功能             │           原因           │             建议              │                                                                                                                                                                               
  ├──────────────────────────────┼──────────────────────────┼───────────────────────────────┤
  │ Stripe 海外支付              │ 已明确推至 v2            │ v2 版本排期                   │                                                                                                                                                                               
  ├──────────────────────────────┼──────────────────────────┼───────────────────────────────┤
  │ 微信支付/支付宝 SDK 真实参数 │ 需接入真实商户密钥       │ 联调阶段配置 .env 中的 key    │                                                                                                                                                                               
  ├──────────────────────────────┼──────────────────────────┼───────────────────────────────┤                                                                                                                                                                               
  │ 性能优化（索引/N+1 深查）    │ 需 production 慢查询日志 │ 上线后用 Bullet + PgHero 定位 │                                                                                                                                                                               
  ├──────────────────────────────┼──────────────────────────┼───────────────────────────────┤                                                                                                                                                                               
  │ Apple 支付（IAP/RevenueCat） │ 需确认业务需求           │ v2 版本                       │
  ├──────────────────────────────┼──────────────────────────┼───────────────────────────────┤                                                                                                                                                                               
  │ Stripe 对账                  │ v2                       │ v2 版本                       │
  └──────────────────────────────┴──────────────────────────┴───────────────────────────────┘          