# Craftlet 商家端 API — 功能测试文档
> **版本**：Week 3 实现版  
> **更新日期**：2026-04-16  
> **测试环境**：`http://localhost:3000`（或联调环境地址）  
> **Swagger UI**：`http://localhost:3000/api-docs`  
> **认证方式**：所有标注 🔒 的接口需在请求头携带 `Authorization: Bearer <Logto JWT Token>`

---

## 目录

1. [前置准备](#前置准备)
2. [模块一：商家入驻申请](#模块一商家入驻申请)
3. [模块二：商家审核状态查询](#模块二商家审核状态查询)
4. [模块三：商家端订单管理](#模块三商家端订单管理)
5. [模块四：商家资料管理](#模块四商家资料管理)
6. [模块五：商家数据看板](#模块五商家数据看板)
7. [模块六：结算单查询](#模块六结算单查询)
8. [端到端完整场景测试](#端到端完整场景测试)
9. [异常场景汇总](#异常场景汇总)

---

## 前置准备

### 1. 获取测试 Token

通过 Logto 登录获取 JWT Access Token，或使用测试环境 Mock Token（联系开发确认 Mock 模式是否已开启）。

```
Authorization: Bearer <your_token>
```

### 2. 准备测试账号

| 角色 | 说明 |
|------|------|
| **普通用户 A** | 未申请入驻，用于测试申请流程 |
| **已申请用户 B** | 已提交申请（submitted），验证重复申请 |
| **已审核商家 C** | merchant_profile.status = `approved`，用于订单/看板/结算测试 |
| **未审核用户 D** | merchant_profile.status = `submitted`，验证权限拦截 |
| **消费者用户 E** | 有待付款订单，供商家端接单测试 |

### 3. 准备测试数据

通过 ActiveAdmin 或 Rails console 创建：

```ruby
# 为已审核商家 C 创建测试订单（消费者端发起，状态需为 paid）
# 订单状态路径：created → paid → accepted → producing → delivered → completed

# 为商家 C 创建结算单（模拟结算系统生成）
Settlement.create!(
  merchant_profile: merchant_c.merchant_profile,
  settlement_no: "ST#{Date.today.strftime('%Y%m%d')}0001",
  period_start: 7.days.ago.to_date,
  period_end: Date.today,
  total_order_amount: 10000,
  total_refund_amount: 500,
  net_amount: 9500,
  status: 'pending_review'
)
```

---

## 模块一：商家入驻申请

### TC-M1-01 ✅ 正常申请入驻

**接口**：`POST /api/v1/merchant/apply` 🔒

**测试步骤**：

1. 使用普通用户 A 的 Token
2. 发送请求：

```json
POST /api/v1/merchant/apply
Content-Type: application/json
Authorization: Bearer <User_A_Token>

{
  "merchant": {
    "shop_name": "测试手工工坊",
    "license_file_key": "licenses/test-2026.jpg",
    "idcard_front_key": "idcards/front-test.jpg",
    "idcard_back_key": "idcards/back-test.jpg",
    "bank_name": "招商银行",
    "bank_branch": "深圳南山支行",
    "address_province": "广东省",
    "address_city": "深圳市",
    "address_district": "南山区",
    "address_detail": "科技园A栋101室"
  }
}
```

**预期结果**：

- HTTP 状态码：`201 Created`
- 响应体：

```json
{
  "success": true,
  "data": {
    "id": <数字>,
    "status": "submitted",
    "shop_name": "测试手工工坊",
    "created_at": "<ISO 8601 时间>"
  }
}
```

**验证点**：
- [ ] HTTP 状态码为 201
- [ ] `data.status` 为 `"submitted"`（非 `"pending"`）
- [ ] `data.shop_name` 与请求一致
- [ ] ActiveAdmin 中可见新的待审核商家资料

---

### TC-M1-02 ❌ 重复申请被拒绝

**接口**：`POST /api/v1/merchant/apply` 🔒

**前提**：用户 A 已成功完成 TC-M1-01

**测试步骤**：使用同一 Token 再次发送相同请求

**预期结果**：

```json
HTTP 422 Unprocessable Entity

{
  "success": false,
  "error": {
    "code": "already_applied",
    "message": "您已提交过入驻申请，请勿重复提交"
  }
}
```

**验证点**：
- [ ] HTTP 状态码为 422
- [ ] `error.code` 为 `"already_applied"`
- [ ] 数据库中未新增 MerchantProfile 记录

---

### TC-M1-03 ❌ 缺少必填字段（shop_name 为空）

**测试步骤**：发送 `shop_name: ""` 的请求

**预期结果**：

```json
HTTP 422 Unprocessable Entity

{
  "success": false,
  "error": {
    "code": "validation_error",
    "message": "Shop name can't be blank"
  }
}
```

**验证点**：
- [ ] HTTP 状态码为 422
- [ ] `error.code` 为 `"validation_error"`

---

### TC-M1-04 ❌ 未携带 Token

**测试步骤**：不添加 `Authorization` 头发送请求

**预期结果**：

```json
HTTP 401 Unauthorized

{
  "success": false,
  "error": {
    "code": "unauthorized",
    "message": "请先登录"
  }
}
```

---

## 模块二：商家审核状态查询

### TC-M2-01 ✅ 查询已申请用户的审核状态

**接口**：`GET /api/v1/merchant/status` 🔒

**测试步骤**：用已申请用户 B（submitted 状态）的 Token 查询

**预期结果**：

```json
HTTP 200 OK

{
  "success": true,
  "data": {
    "status": "submitted",
    "shop_name": "<店铺名>",
    "message": "",
    "rejected_reason": null,
    "approved_at": null,
    "rejected_at": null,
    "created_at": "<ISO 8601>"
  }
}
```

---

### TC-M2-02 ✅ 查询未申请用户的状态

**前提**：使用从未申请过的用户

**预期结果**：

```json
HTTP 200 OK

{
  "success": true,
  "data": {
    "status": "not_applied",
    "message": "..."
  }
}
```

---

### TC-M2-03 ✅ 查询已通过审核商家的状态

**前提**：使用已审核商家 C 的 Token

**预期结果**：
- [ ] `data.status` 为 `"approved"`
- [ ] `data.approved_at` 有时间值
- [ ] `data.rejected_reason` 为 null

---

## 模块三：商家端订单管理

> ⚠️ **前提**：所有接口要求 `merchant_profile.status == "approved"`，未审核商家返回 403。

### TC-M3-01 ✅ 获取商家订单列表

**接口**：`GET /api/v1/merchant/orders` 🔒

**前提**：已审核商家 C，且存在属于该商家的订单

**测试步骤**：发送请求（无额外参数）

**预期结果**：

```json
HTTP 200 OK

{
  "success": true,
  "data": [
    {
      "id": <数字>,
      "order_no": "ORD...",
      "status": "paid",
      "total_amount": "299.0",
      "currency": "CNY",
      "customer_nickname": "<消费者昵称或null>",
      "paid_at": "<ISO 8601 或 null>",
      "created_at": "<ISO 8601>"
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
- [ ] 只返回当前商家的订单（不含其他商家的订单）
- [ ] 包含分页 meta
- [ ] 按 `created_at` 倒序排列

---

### TC-M3-02 ✅ 按状态筛选订单

**接口**：`GET /api/v1/merchant/orders?status=paid` 🔒

**预期结果**：
- [ ] `data` 中所有订单 `status` 均为 `"paid"`
- [ ] 分页 `total_count` 与实际 paid 状态订单数一致

---

### TC-M3-03 ✅ 接单（paid → accepted）

**接口**：`POST /api/v1/merchant/orders/:id/accept` 🔒

**前提**：存在一个 `status = "paid"` 的商家订单，记录其 `id`

**测试步骤**：

```
POST /api/v1/merchant/orders/{订单ID}/accept
Authorization: Bearer <Merchant_C_Token>
```

**预期结果**：

```json
HTTP 200 OK

{
  "success": true,
  "data": {
    "id": <订单ID>,
    "status": "accepted",
    "accepted_at": "<ISO 8601>",
    ...
  }
}
```

**验证点**：
- [ ] HTTP 状态码 200
- [ ] `data.status` 变为 `"accepted"`
- [ ] `data.accepted_at` 有时间值
- [ ] 数据库中订单状态已更新

---

### TC-M3-04 ❌ 接单状态不合法（非 paid 状态）

**前提**：存在一个 `status = "created"` 的订单

**预期结果**：

```json
HTTP 422 Unprocessable Entity

{
  "success": false,
  "error": {
    "code": "invalid_state",
    "message": "当前订单状态不允许接单"
  }
}
```

---

### TC-M3-05 ✅ 开始制作（accepted → producing）

**接口**：`POST /api/v1/merchant/orders/:id/start_producing` 🔒

**前提**：存在 `status = "accepted"` 的订单（可先完成 TC-M3-03）

**预期结果**：
- [ ] HTTP 200
- [ ] `data.status` 为 `"producing"`
- [ ] `data.producing_at` 有时间值

---

### TC-M3-06 ✅ 发货（producing → delivered）

**接口**：`POST /api/v1/merchant/orders/:id/deliver` 🔒

**前提**：存在 `status = "producing"` 的订单（可先完成 TC-M3-05）

**预期结果**：
- [ ] HTTP 200
- [ ] `data.status` 为 `"delivered"`
- [ ] `data.delivered_at` 有时间值

---

### TC-M3-07 ❌ 未审核商家访问订单管理被拦截

**前提**：使用用户 D（merchant_profile.status = submitted）

**预期结果**：

```json
HTTP 403 Forbidden

{
  "success": false,
  "error": {
    "code": "merchant_not_approved",
    "message": "需要已审核通过的商家账号"
  }
}
```

---

### TC-M3-08 ❌ 查看他人订单被拒绝

**前提**：已审核商家 C 尝试访问属于其他商家的订单 ID

**预期结果**：
- [ ] HTTP 404 Not Found

---

## 模块四：商家资料管理

### TC-M4-01 ✅ 查看商家自己的资料

**接口**：`GET /api/v1/merchant/profile` 🔒

**前提**：已审核商家 C 的 Token

**预期结果**：

```json
HTTP 200 OK

{
  "success": true,
  "data": {
    "id": <数字>,
    "status": "approved",
    "shop_name": "<店铺名>",
    "full_address": "<省市区详细>",
    "address_province": "广东省",
    "address_city": "深圳市",
    "address_district": "<区县或null>",
    "address_detail": "<详细地址或null>",
    "bank_name": "<银行名或null>",
    "bank_branch": "<支行或null>",
    "masked_bank_account_no": "****（脱敏显示）",
    "license_file_key": "<OSS Key 或null>",
    "idcard_front_key": "<OSS Key 或null>",
    "idcard_back_key": "<OSS Key 或null>",
    "deposit_amount": "<金额或null>",
    "approved_at": "<ISO 8601>",
    "created_at": "<ISO 8601>"
  }
}
```

**验证点**：
- [ ] `masked_bank_account_no` 为脱敏格式（`****...`），不暴露真实账号
- [ ] `license_file_key` 等 OSS key 正确返回（供前端生成预签名 URL）
- [ ] 不返回未申请用户的资料（404）

---

### TC-M4-02 ✅ 更新商家资料

**接口**：`PATCH /api/v1/merchant/profile` 🔒

**测试步骤**：

```json
PATCH /api/v1/merchant/profile
Authorization: Bearer <Merchant_C_Token>
Content-Type: application/json

{
  "merchant": {
    "shop_name": "新工坊名称（已更新）",
    "bank_name": "工商银行",
    "bank_branch": "深圳科技园支行",
    "address_province": "广东省",
    "address_city": "深圳市",
    "address_district": "南山区",
    "address_detail": "科技园B栋202室"
  }
}
```

**预期结果**：
- [ ] HTTP 200
- [ ] `data.shop_name` 为 `"新工坊名称（已更新）"`
- [ ] `data.bank_name` 为 `"工商银行"`
- [ ] 数据库中记录已更新

---

### TC-M4-03 ❌ shop_name 置空报错

**预期结果**：HTTP 422，`error.code = "validation_error"`

---

### TC-M4-04 ❌ 未申请入驻的用户查看商家资料

**预期结果**：HTTP 404，提示商家资料不存在

---

## 模块五：商家数据看板

### TC-M5-01 ✅ 获取看板统计数据

**接口**：`GET /api/v1/merchant/dashboard` 🔒

**前提**：已审核商家 C，有若干不同状态的订单

**预期结果**：

```json
HTTP 200 OK

{
  "success": true,
  "data": {
    "today_orders_count": <今日新增订单数>,
    "pending_accept_count": <paid 状态订单数>,
    "producing_count": <producing 状态订单数>,
    "delivering_count": <delivered 状态订单数>,
    "this_month_completed": <本月 completed 数>,
    "this_month_revenue": "<本月 completed 订单金额合计字符串>",
    "total_completed_count": <历史累计 completed 数>,
    "merchant_status": "approved"
  }
}
```

**验证点**：
- [ ] `pending_accept_count` 与实际 `paid` 状态订单数一致
- [ ] `this_month_revenue` 只统计本月已完成订单（completed_at 在当月）
- [ ] 统计数据不包含其他商家的订单
- [ ] `merchant_status` 为 `"approved"`

---

### TC-M5-02 ❌ 未审核商家访问看板

**前提**：用户 D（submitted 状态）

**预期结果**：HTTP 403，`error.code = "merchant_not_approved"`

---

## 模块六：结算单查询

### TC-M6-01 ✅ 获取结算单列表

**接口**：`GET /api/v1/merchant/settlements` 🔒

**前提**：商家 C 有至少 1 条结算单（通过 Rails console 或管理后台创建）

**预期结果**：

```json
HTTP 200 OK

{
  "success": true,
  "data": [
    {
      "id": <数字>,
      "settlement_no": "ST202604010001",
      "status": "pending_review",
      "period_start": "2026-04-01",
      "period_end": "2026-04-07",
      "total_order_amount": "10000.0",
      "total_refund_amount": "500.0",
      "net_amount": "9500.0",
      "approved_at": null,
      "paid_out_at": null,
      "confirmed_at": null,
      "created_at": "<ISO 8601>"
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
- [ ] 只返回当前商家的结算单
- [ ] 其他商家的结算单不出现在列表中
- [ ] 支持分页（总条数 > 20 时）

---

### TC-M6-02 ✅ 查看结算单详情

**接口**：`GET /api/v1/merchant/settlements/:id` 🔒

**前提**：已知商家 C 的某个结算单 ID

**预期结果**：

```json
HTTP 200 OK

{
  "success": true,
  "data": {
    "id": <数字>,
    "settlement_no": "ST...",
    "status": "confirmed",
    "period_start": "2026-04-01",
    "period_end": "2026-04-07",
    "total_order_amount": "10000.0",
    "total_refund_amount": "500.0",
    "deposit_deduction": "0.0",
    "penalty_amount": "0.0",
    "net_amount": "9500.0",
    "payout_reference": "<打款凭证号或null>",
    "failure_reason": null,
    "frozen_reason": null,
    "paid_out_at": "<ISO 8601 或null>",
    "confirmed_at": "<ISO 8601 或null>",
    "created_at": "<ISO 8601>"
  }
}
```

**验证点**：
- [ ] 详情包含 `deposit_deduction`、`penalty_amount` 等明细字段（列表接口不含）
- [ ] 确认状态下 `confirmed_at` 有时间值

---

### TC-M6-03 ❌ 查看他人结算单

**预期结果**：HTTP 404 Not Found

---

### TC-M6-04 ❌ 查看不存在的结算单

**预期结果**：HTTP 404 Not Found

---

## 端到端完整场景测试

### E2E-01：商家入驻 → 审核 → 接单完整流程

| 步骤 | 操作 | 期望结果 |
|------|------|---------|
| 1 | 用户 A 调用 `POST /api/v1/merchant/apply` | 201，status=submitted |
| 2 | 管理员登录 ActiveAdmin，审核通过 | merchant_profile.status = approved |
| 3 | 用户 A 调用 `GET /api/v1/merchant/status` | status=approved，approved_at 有值 |
| 4 | 消费者 E 创建订单并完成支付 | 订单 status=paid |
| 5 | 商家 A 调用 `GET /api/v1/merchant/orders` | 见到 paid 状态订单 |
| 6 | 商家 A 调用 `POST /api/v1/merchant/orders/:id/accept` | status 变为 accepted |
| 7 | 商家 A 调用 `POST /api/v1/merchant/orders/:id/start_producing` | status 变为 producing |
| 8 | 商家 A 调用 `POST /api/v1/merchant/orders/:id/deliver` | status 变为 delivered |
| 9 | 商家 A 调用 `GET /api/v1/merchant/dashboard` | producing_count、delivering_count 正确反映 |

---

### E2E-02：结算单查询

| 步骤 | 操作 | 期望结果 |
|------|------|---------|
| 1 | 管理员通过结算功能生成结算单 | Settlement 记录创建，status=pending_review |
| 2 | 商家调用 `GET /api/v1/merchant/settlements` | 见到结算单列表 |
| 3 | 商家调用 `GET /api/v1/merchant/settlements/:id` | 见到明细金额（deposit_deduction 等） |
| 4 | 管理员审批、打款 | status 变为 paid_out → confirmed |
| 5 | 商家刷新详情 | `confirmed_at` 有值，`payout_reference` 有凭证号 |

---

## 异常场景汇总

| 场景 | 接口 | 预期状态码 | error.code |
|------|------|-----------|------------|
| 无 Token | 所有 🔒 接口 | 401 | `unauthorized` |
| Token 无效/过期 | 所有 🔒 接口 | 401 | `unauthorized` |
| 重复申请入驻 | POST /merchant/apply | 422 | `already_applied` |
| shop_name 为空 | POST /merchant/apply | 422 | `validation_error` |
| 未审核商家访问订单列表 | GET /merchant/orders | 403 | `merchant_not_approved` |
| 未审核商家接单 | POST /merchant/orders/:id/accept | 403 | `merchant_not_approved` |
| 订单状态不符合接单条件 | POST /merchant/orders/:id/accept | 422 | `invalid_state` |
| 订单状态不符合开始制作 | POST /merchant/orders/:id/start_producing | 422 | `invalid_state` |
| 订单状态不符合发货 | POST /merchant/orders/:id/deliver | 422 | `invalid_state` |
| 查看他人订单 | GET /merchant/orders/:id | 404 | — |
| 查看他人结算单 | GET /merchant/settlements/:id | 404 | — |
| 查看不存在的资源 | 任何 GET /:id | 404 | `not_found` |
| 无商家资料查看 profile | GET /merchant/profile | 404 | `not_found` |
| shop_name 更新为空 | PATCH /merchant/profile | 422 | `validation_error` |
| 未审核商家查看看板 | GET /merchant/dashboard | 403 | `merchant_not_approved` |

---

## 注意事项

1. **`accept` 接口的 merchant_active? guard**  
   `accept!` 事件会检查商家 `user.status == "active"` 且 `merchant_profile.approved?`，两个条件都必须满足。若商家被管理员禁用（status != active），接单会返回 422 `invalid_state`。

2. **看板统计时区**  
   `today_orders_count` 和 `this_month_revenue` 按服务器时区（UTC+8）统计。跨日期边界时需注意。

3. **结算单唯一约束**  
   同一商家同一周期（period_start + period_end）只能有一条结算单。测试时如需创建多条，需使用不同周期。

4. **订单状态流转不可逆**  
   `accepted → producing → delivered` 是单向流转，不可回退。测试时需按顺序逐步推进。

5. **Swagger UI 测试**  
   访问 `http://localhost:3000/api-docs`，选择 **商家** 标签页，点击 **Authorize** 输入 Bearer Token 后即可直接在 UI 中测试所有接口。
