# Week 1 测试手册 / Week 1 Test Manual
# Craftlet — 认证层改造（Logto JWT 中间件）
# Craftlet — Authentication Layer Refactor (Logto JWT Middleware)

**版本 / Version:** Week 1  
**日期 / Date:** 2026-04-13  
**环境 / Environment:** 测试环境 `http://localhost:3000`  
**前置条件 / Prerequisites:** Week 0 已完成，数据库已迁移 / Week 0 complete, DB migrated

---

## 目录 / Table of Contents

1. [快速启动 / Quick Start](#快速启动)
2. [RSpec 测试命令 / RSpec Commands](#rspec-测试命令)
3. [Logto JWT Token 获取说明 / How to Get a Logto JWT](#logto-jwt-token-获取)
4. [TC-W1-01: 受保护端点认证 / Protected Endpoint Auth](#tc-w1-01-受保护端点认证)
5. [TC-W1-02: 公开端点无需认证 / Public Endpoint No Auth](#tc-w1-02-公开端点无需认证)
6. [TC-W1-03: 自动用户同步 / Auto User Sync](#tc-w1-03-自动用户同步)
7. [TC-W1-04: 语言切换 / Locale Switching](#tc-w1-04-语言切换)
8. [TC-W1-05: Logto Webhook](#tc-w1-05-logto-webhook)
9. [TC-W1-06: 商家状态 API / Merchant Status API](#tc-w1-06-商家状态-api)
10. [TC-W1-07: 优惠券 API / Coupons API](#tc-w1-07-优惠券-api)
11. [TC-W1-08: 反馈提交 API / Feedback API](#tc-w1-08-反馈提交-api)
12. [TC-W1-09: 限流验证 / Rate Limiting](#tc-w1-09-限流验证)
13. [已知问题 / Known Issues](#已知问题)
14. [验收检查清单 / Acceptance Checklist](#验收检查清单)

---

## 快速启动

```bash
# 1. 确认服务器运行 / Verify server is running
curl http://localhost:3000/up
# Expected: 200 OK

# 2. 运行所有 Week 1 单元测试
bundle exec rspec spec/services/auth/ spec/requests/auth_flow_spec.rb \
  spec/requests/api/v1/merchants_spec.rb spec/requests/api/v1/feedbacks_spec.rb \
  --format documentation
# Expected: 全绿 0 failures / all green

# 3. 运行 Week 0 + Week 1 联合回归
bundle exec rspec spec/models/concerns/uuid_identity_spec.rb \
  spec/services/auth/ spec/requests/auth_flow_spec.rb \
  spec/requests/api/v1/ --format progress
# Expected: 89 examples, 0 failures
```

---

## RSpec 测试命令

### Day 1 — JWT 验证核心 / JWT Verification Core
```bash
bundle exec rspec spec/services/auth/jwt_verifier_spec.rb --format documentation
# 15 examples, 0 failures
# 覆盖 / Covers:
#   - 合法 RS256 token → TokenClaims
#   - 过期 token → VerificationError (expired)
#   - 错误签名密钥 → VerificationError
#   - 错误 issuer → VerificationError (issuer)
#   - 错误 audience → VerificationError (audience)
#   - 畸形 token → VerificationError
#   - 缺少 LOGTO_ISSUER / LOGTO_AUDIENCE → VerificationError
#   - HS256 算法混淆攻击 → VerificationError
```

### Day 3 — 用户同步 / User Sync
```bash
bundle exec rspec spec/services/auth/user_sync_service_spec.rb --format documentation
# 15 examples, 0 failures
# 覆盖 / Covers:
#   - 首次登录创建用户
#   - 幂等性（同一 sub 多次调用）
#   - 字段更新（email/nickname/phone）
#   - 手机号用户（无邮箱）
#   - blank sub → SyncError
```

### 端到端认证流程 / End-to-End Auth Flow
```bash
bundle exec rspec spec/requests/auth_flow_spec.rb --format documentation
# 18 examples, 0 failures
# 覆盖 / Covers:
#   - 无 token → 401
#   - 无效 token → 401
#   - 有效 token → 200
#   - 公开端点（banners/announcements/faqs）无 token → 200
#   - 首次登录自动创建 User
#   - 中文 / 英文错误信息
#   - Webhook 签名验证
#   - Webhook User.Deleted 停用用户
```

---

## Logto JWT Token 获取

### 方法一：Logto Console（管理面板）
```
1. 登录 Logto Console: https://your-logto.example.com
2. 进入 Applications → 找到 Craftlet App
3. 复制 App ID 和 App Secret
4. POST https://your-logto.example.com/oidc/token
   Content-Type: application/x-www-form-urlencoded

   grant_type=client_credentials
   &client_id=<APP_ID>
   &client_secret=<APP_SECRET>
   &resource=https://api.craftlet.com
   &scope=openid profile email phone_number
```

### 方法二：Logto SDK (移动端/前端)
```javascript
// logto-js example
const logtoClient = new LogtoClient({
  endpoint: 'https://your-logto.example.com',
  appId: 'your-app-id',
  resources: ['https://api.craftlet.com'],
});
await logtoClient.signIn(redirectUri);
const token = await logtoClient.getAccessToken('https://api.craftlet.com');
```

### 方法三：测试环境 Mock Token（开发环境专用）
```bash
# 在测试中 stub JwtVerifier：
# allow(Auth::JwtVerifier).to receive(:call).and_return(
#   Auth::TokenClaims.new(sub: 'test-sub', email: 'test@example.com', ...)
# )
```

> ⚠️ 以下 curl 示例中，`<TOKEN>` 请替换为实际 Logto JWT。  
> ⚠️ In the curl examples below, replace `<TOKEN>` with an actual Logto JWT.

---

## TC-W1-01 受保护端点认证

### T01-01: 无 token → 401
```bash
curl -i http://localhost:3000/api/v1/merchant/status

# Expected HTTP 401
# Expected body:
{
  "success": false,
  "error": {
    "code": "unauthorized",
    "message": "缺少认证 Token，请在请求头中携带 Authorization: Bearer <token>"
  }
}
```

### T01-02: Bearer token 格式错误 → 401
```bash
curl -i http://localhost:3000/api/v1/merchant/status \
  -H "Authorization: Token invalid-format"

# Expected HTTP 401 (not "Bearer" prefix)
```

### T01-03: 无效/伪造 token → 401
```bash
curl -i http://localhost:3000/api/v1/merchant/status \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.fake.token"

# Expected HTTP 401
# Expected body error.code: "unauthorized"
```

### T01-04: 过期 token → 401
```bash
# 使用已过期的 Logto token（exp 在当前时间之前）
curl -i http://localhost:3000/api/v1/merchant/status \
  -H "Authorization: Bearer <EXPIRED_TOKEN>"

# Expected HTTP 401
```

### T01-05: 合法 token → 200
```bash
curl -i http://localhost:3000/api/v1/merchant/status \
  -H "Authorization: Bearer <VALID_TOKEN>"

# Expected HTTP 200
# Expected body:
{
  "success": true,
  "data": {
    "status": "not_applied",
    "message": "您尚未申请入驻"
  }
}
```

---

## TC-W1-02 公开端点无需认证

### T02-01: 横幅列表（无 token）
```bash
curl -i http://localhost:3000/api/v1/banners

# Expected HTTP 200
```

### T02-02: 公告列表（无 token）
```bash
curl -i http://localhost:3000/api/v1/announcements

# Expected HTTP 200
```

### T02-03: FAQ 列表（无 token）
```bash
curl -i http://localhost:3000/api/v1/faqs

# Expected HTTP 200
```

### T02-04: 公开端点 + 无效 token 不影响响应
```bash
# 公开端点不验证 token，即使携带无效 token 也应返回 200
curl -i http://localhost:3000/api/v1/banners \
  -H "Authorization: Bearer garbage.token.value"

# Expected HTTP 200 (not 401)
```

---

## TC-W1-03 自动用户同步

### T03-01: 首次登录自动创建 User 记录
```bash
# 前提：不存在 external_id = 'logto-xxx' 的 User
# Prerequisite: no User with external_id matching the token's sub

curl -i http://localhost:3000/api/v1/merchant/status \
  -H "Authorization: Bearer <NEW_USER_TOKEN>"

# Expected HTTP 200

# 验证 / Verify in Rails console:
# User.find_by(external_id: '<logto_sub_from_token>')
# => #<User id: ..., auth_provider: "logto", email: "...">
```

### T03-02: 同一 sub 多次登录不重复创建
```bash
# 发两次请求
curl http://localhost:3000/api/v1/merchant/status -H "Authorization: Bearer <TOKEN>"
curl http://localhost:3000/api/v1/merchant/status -H "Authorization: Bearer <TOKEN>"

# 验证 / Verify:
# User.where(external_id: '<sub>').count  => 1  (not 2)
```

### T03-03: 信息更新同步
```bash
# Logto 中更新用户 email 后，下次登录时本地 User.email 应更新
# Update user email in Logto Console, then:

curl http://localhost:3000/api/v1/merchant/status \
  -H "Authorization: Bearer <TOKEN_WITH_NEW_EMAIL>"

# Verify:
# User.find_by(external_id: '<sub>').email  => "new-email@example.com"
```

---

## TC-W1-04 语言切换

### T04-01: 默认中文错误信息
```bash
curl -i http://localhost:3000/api/v1/merchant/status
# No Authorization header → 401

# Expected message: "缺少认证 Token，请在请求头中携带 Authorization: Bearer <token>"
```

### T04-02: 切换为英文（params）
```bash
curl -i "http://localhost:3000/api/v1/merchant/status?locale=en"

# Expected message: "Authentication token is missing. Please include Authorization: Bearer <token> in your request header"
```

### T04-03: 切换为英文（Accept-Language header）
```bash
curl -i http://localhost:3000/api/v1/merchant/status \
  -H "Accept-Language: en,zh-CN;q=0.8"

# Expected: English error message
```

### T04-04: 商家状态英文响应
```bash
curl -i "http://localhost:3000/api/v1/merchant/status?locale=en" \
  -H "Authorization: Bearer <VALID_TOKEN>"

# Expected (no merchant profile):
{
  "success": true,
  "data": {
    "status": "not_applied",
    "message": "You have not applied for merchant onboarding yet"
  }
}
```

---

## TC-W1-05 Logto Webhook

> 环境变量需设置 / Requires env var:  
> `LOGTO_WEBHOOK_SECRET=your-webhook-secret`

### T05-01: 有效签名 Webhook 事件
```bash
WEBHOOK_SECRET="your-secret"
PAYLOAD='{"event":"User.Deleted","hookId":"hook-001","data":{"id":"logto-user-123"}}'
SIG=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" | awk '{print $2}')

curl -i -X POST http://localhost:3000/api/webhooks/logto \
  -H "Content-Type: application/json" \
  -H "logto-signature-sha-256: $SIG" \
  -d "$PAYLOAD"
# Expected body: {"success":true,"data":{"received":true}}
```

### T05-02: 用户删除事件停用本地用户
```bash
# 前提：存在 external_id = 'logto-user-123' 的 User
# Prerequisite: User with external_id = 'logto-user-123' exists

# 同 T05-01 步骤，发送 User.Deleted 事件
# Then verify:
# User.find_by_external_id_was('logto-user-123')
# => User with status: 'deactivated', external_id: nil

PAYLOAD='{"event":"User.Deleted","hookId":"hook-001","data":{"id":"logto-user-123"}}'
SIG=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" | awk '{print $2}')

curl -X POST http://localhost:3000/api/webhooks/logto \
  -H "Content-Type: application/json" \
  -H "logto-signature-sha-256: $SIG" \
  -d "$PAYLOAD"
```

### T05-03: 签名错误 → 401
```bash
curl -i -X POST http://localhost:3000/api/webhooks/logto \
  -H "Content-Type: application/json" \
  -H "logto-signature-sha-256: wrong-signature" \
  -d '{"event":"User.Deleted","hookId":"hook-001","data":{"id":"xxx"}}'

# Expected HTTP 401
# Expected body error.code: "invalid_signature"
```

### T05-04: 缺少签名头 → 401
```bash
curl -i -X POST http://localhost:3000/api/webhooks/logto \
  -H "Content-Type: application/json" \
  -d '{"event":"User.Deleted","hookId":"hook-001","data":{"id":"xxx"}}'

# Expected HTTP 401
# Expected body error.code: "missing_signature"
```

### T05-05: User.Data.Updated 事件同步
```bash
PAYLOAD='{
  "event": "User.Data.Updated",
  "hookId": "hook-002",
  "data": {
    "id": "logto-user-123",
    "primaryEmail": "updated@example.com",
    "name": "Updated Name"
  }
}'
SIG=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" | awk '{print $2}')

curl -X POST http://localhost:3000/api/webhooks/logto \
  -H "Content-Type: application/json" \
  -H "logto-signature-sha-256: $SIG" \
  -d "$PAYLOAD"

# Expected: User.find_by(external_id: 'logto-user-123').email => 'updated@example.com'
```

---

## TC-W1-06 商家状态 API

### T06-01: 未申请入驻
```bash
curl -i http://localhost:3000/api/v1/merchant/status \
  -H "Authorization: Bearer <TOKEN_NO_PROFILE>"

# Expected:
{
  "success": true,
  "data": {
    "status": "not_applied",
    "message": "您尚未申请入驻"
  }
}
```

### T06-02: 已申请，审核中
```bash
# 前提：对应 User 有 MerchantProfile.status = 'submitted'

curl -i http://localhost:3000/api/v1/merchant/status \
  -H "Authorization: Bearer <TOKEN_WITH_SUBMITTED_PROFILE>"

# Expected data.status: "submitted"
# Expected data.message: "您的资料正在审核中，请耐心等待"
```

### T06-03: 已通过审核
```bash
# MerchantProfile.status = 'approved'
# Expected data.message: "恭喜！您的商家入驻申请已通过"
```

### T06-04: 审核被拒
```bash
# MerchantProfile.status = 'rejected'
# Expected data.message: "很抱歉，您的申请未通过审核"
# Expected data.rejected_reason: "<拒绝原因>"
```

---

## TC-W1-07 优惠券 API

### T07-01: 获取优惠券列表（需认证）
```bash
curl -i http://localhost:3000/api/v1/coupons \
  -H "Authorization: Bearer <TOKEN>"

# Expected HTTP 200
```

### T07-02: 未认证 → 401
```bash
curl -i http://localhost:3000/api/v1/coupons

# Expected HTTP 401
```

### T07-03: 兑换码换取优惠券
```bash
curl -i -X POST http://localhost:3000/api/v1/coupons/redeem \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"code": "WELCOME2026"}'

# Expected HTTP 201 (成功) or 422 (兑换码无效)
```

---

## TC-W1-08 反馈提交 API

> ⚠️ KI-W1-01: 验证码功能在 API-only 模式下降级，验证码校验自动跳过。  
> ⚠️ KI-W1-01: Captcha is gracefully degraded in API-only mode; validation auto-passes.

### T08-01: 匿名提交反馈（无 token）
```bash
curl -i -X POST http://localhost:3000/api/v1/feedbacks \
  -H "Content-Type: application/json" \
  -d '{
    "feedback": {
      "feedback_type": "bug_report",
      "subject": "登录按钮无响应",
      "content": "点击登录按钮后页面没有任何反应，复现步骤：...",
      "submitter_name": "张三",
      "submitter_email": "zhangsan@example.com"
    }
  }'

# Expected HTTP 201
# Expected body:
{
  "success": true,
  "data": {
    "id": 1,
    "tracking_number": "FB20260413XXXX",
    "message": "感谢您的反馈！我们会尽快处理并通过邮件回复您。",
    "estimated_response_time": "48小时内"
  }
}
```

### T08-02: 已登录用户提交反馈
```bash
curl -i -X POST http://localhost:3000/api/v1/feedbacks \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "feedback": {
      "feedback_type": "feature_request",
      "subject": "希望支持暗色主题",
      "content": "建议增加暗色主题选项",
      "submitter_name": "李四",
      "submitter_email": "lisi@example.com"
    }
  }'

# Expected HTTP 201
# feedback.user_id 应自动关联已登录用户
```

### T08-03: 参数缺失 → 400
```bash
curl -i -X POST http://localhost:3000/api/v1/feedbacks \
  -H "Content-Type: application/json" \
  -d '{}'

# Expected HTTP 400
# Expected body error.code: "parameter_missing"
```

### T08-04: 查询反馈状态
```bash
curl -i http://localhost:3000/api/v1/feedbacks/FB20260413XXXX

# Expected HTTP 200
# Expected body:
{
  "success": true,
  "data": {
    "tracking_number": "FB20260413XXXX",
    "status": "...",
    "submitted_at": "2026-04-13T...",
    "last_update": "..."
  }
}
```

### T08-05: 不存在的跟踪号 → 404
```bash
curl -i http://localhost:3000/api/v1/feedbacks/INVALID-999

# Expected HTTP 404
# Expected body error.code: "not_found"
```

---

## TC-W1-09 限流验证

### T09-01: Webhook 端点限流（30 次/分钟）
```bash
# 连续发送 31 次请求（签名可以错误，因为限流在签名验证之前）
for i in $(seq 1 31); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -X POST http://localhost:3000/api/webhooks/logto \
    -H "Content-Type: application/json" \
    -d '{"event":"ping"}'
done

# 前 30 次：401（签名错误）
# 第 31 次：429 Too Many Requests
# Expected 429 body:
# {"success":false,"error":{"code":"rate_limited","message":"请求过于频繁..."}}
```

### T09-02: 全局 IP 限流（300 次/分钟）
```bash
# 超过 300 次请求/分钟后期望 429
# 正常使用不会触发此限制
```

---

## 已知问题 / Known Issues

| 编号 | 级别 | 描述 | 影响 | 解决方案 |
|------|------|------|------|----------|
| KI-W1-01 | 🟡 中 | `GET /api/v1/feedbacks/captcha` 依赖 RuCaptcha+session，与 ActionController::API 不兼容。captcha_image 返回 null。 | 验证码功能在 API-only 模式下不可用 | 迁移至无状态验证码（Google reCAPTCHA v3）；POST /feedbacks 的 captcha 校验已降级为自动通过，由 Rack::Attack 限流防刷 |
| KI-W1-02 | 🟡 中 | JWKS 缓存（Redis）：若 Redis 不可用，每次请求均调用 Logto JWKS 网络接口 | Redis 故障时认证性能下降 | Redis 故障降级日志已记录（warn 级别）；可增加本地内存缓存作为二级缓存 |
| KI-W1-03 | 🟢 低 | `factories.rb` 中 User factory 含 `jti: SecureRandom.uuid` 字段，该字段已从 Week 0 迁移中移除 | 工厂方法调用会有 DB 警告 | 待更新 factories.rb 移除 jti 字段 |

---

## 验收检查清单 / Acceptance Checklist

### 安全性 / Security
- [ ] `GET /api/v1/merchant/status`（无 token）→ 401 with missing_token code
- [ ] `GET /api/v1/merchant/status`（伪造 token）→ 401
- [ ] `GET /api/v1/merchant/status`（过期 token）→ 401
- [ ] `POST /api/webhooks/logto`（错误签名）→ 401 with invalid_signature
- [ ] `POST /api/webhooks/logto`（无签名头）→ 401 with missing_signature
- [ ] HS256 算法混淆攻击被拒绝（JwtVerifier 只接受 RS256）

### 功能 / Functionality
- [ ] 有效 Logto JWT → 认证通过，返回 200
- [ ] 首次登录自动创建 User（external_id = sub，auth_provider = 'logto'）
- [ ] 再次登录不重复创建 User（幂等性）
- [ ] Logto 信息更新后下次登录同步 email/phone/name
- [ ] `GET /api/v1/banners`（无 token）→ 200（公开端点）
- [ ] `GET /api/v1/announcements`（无 token）→ 200
- [ ] `GET /api/v1/faqs`（无 token）→ 200
- [ ] `User.Deleted` Webhook 停用本地用户（external_id = nil, status = 'deactivated'）
- [ ] `User.Data.Updated` Webhook 同步 email/name/phone

### 国际化 / I18n
- [ ] 默认（无 locale 参数）→ 中文错误信息
- [ ] `?locale=en` → 英文错误信息
- [ ] Accept-Language: en → 英文错误信息
- [ ] 商家状态 message 支持中英文切换
- [ ] 所有 API 错误码（unauthorized/not_found/server_error 等）均有中英文翻译

### 兼容性 / Compatibility
- [ ] Week 0 所有 UUID 转换测试仍通过（uuid_identity_spec）
- [ ] `User#customer_orders` 和 `#merchant_orders` 仍正常返回数据
- [ ] ActiveAdmin 登录（`/admin`）不受影响
- [ ] `devise_for :users, only: [:passwords]`（密码重置）路由正常

### 架构清洁度 / Architecture Hygiene
- [ ] `gem 'devise-jwt'` 已从 Gemfile 注释掉
- [ ] `app/controllers/api/v1/users/sessions_controller.rb` 已删除
- [ ] `config/initializers/rack_attack.rb` 中 `logins/ip` 和 `logins/email` 已移除
- [ ] `config/initializers/rack_attack.rb` 中新增 `webhooks/logto/ip` 限流规则
- [ ] `app/controllers/api/v1/merchants_controller.rb` 继承 `BaseController`
- [ ] `BaseController` 包含 `ExternalJwtAuthenticatable` 和 `ApiResponse`

---

## 附录：环境变量清单 / Appendix: Environment Variables

```bash
# 必须 / Required
LOGTO_JWKS_URI=https://your-logto.example.com/oidc/jwks
LOGTO_ISSUER=https://your-logto.example.com/oidc
LOGTO_AUDIENCE=https://api.craftlet.com

# Webhook（使用 Webhook 功能时必须）/ Required if using Webhooks
LOGTO_WEBHOOK_SECRET=<从 Logto Console 复制 / Copy from Logto Console>

# 可选 / Optional
REDIS_URL=redis://localhost:6379/0  # 默认值 / default
```

---

## 附录：响应格式速查 / Appendix: Response Format Reference

### 成功响应 / Success Response
```json
{
  "success": true,
  "data": { ... }
}
```

### 分页响应 / Paginated Response
```json
{
  "success": true,
  "data": [...],
  "meta": {
    "current_page": 1,
    "total_pages": 5,
    "total_count": 48,
    "per_page": 10
  }
}
```

### 错误响应 / Error Response
```json
{
  "success": false,
  "error": {
    "code": "unauthorized",
    "message": "请先登录"
  }
}
```

### 常见错误码 / Common Error Codes
| code | HTTP | 含义 |
|------|------|------|
| `unauthorized` | 401 | 未登录 |
| `missing_token` | 401 | 缺少 Bearer token |
| `invalid_token` | 401 | token 无效/过期 |
| `user_sync_failed` | 401 | 用户同步失败 |
| `forbidden` | 403 | 无权限 |
| `not_found` | 404 | 资源不存在 |
| `parameter_missing` | 400 | 缺少必要参数 |
| `validation_error` | 422 | 数据校验失败 |
| `rate_limited` | 429 | 请求过于频繁 |
| `invalid_signature` | 401 | Webhook 签名错误 |
| `missing_signature` | 401 | Webhook 缺少签名头 |
| `server_error` | 500 | 服务器内部错误 |
