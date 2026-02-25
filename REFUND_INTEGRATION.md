# 退款集成测试文档 — REFUND_INTEGRATION

> 生成时间: 2026-02-25

---

## ✅ 已完成功能

### 1. ProcessRefundJob（退款异步处理）
| 功能点 | 状态 | 说明 |
|--------|------|------|
| Provider 智能分发 | ✅ 完成 | 根据 `payment.channel` 自动选择 WeChat/Alipay provider |
| 幂等处理 | ✅ 完成 | 非 `pending` 状态直接跳过，不重复执行 |
| 退款成功状态联动 | ✅ 完成 | `refund → succeeded` + `order → refunded`（AASM 守卫） |
| 错误码分类 | ✅ 完成 | 可重试错误 → 抛异常由 Sidekiq 重试；不可重试 → `status = failed` |
| AuditLog 审计 | ✅ 完成 | 成功/失败均记录完整日志 |
| `provider_refund_no` 存储 | ✅ 完成 | Provider 返回的退款单号写入 refund |
| `response_payload` 记录 | ✅ 完成 | 原始 Provider 响应完整保留 |

### 2. 回调 Endpoint（WeChat / Alipay）
| 功能点 | 状态 | 说明 |
|--------|------|------|
| `POST /api/payments/callbacks/wechat` | ✅ 完成 | JSON body 解析，返回 `{"code":"SUCCESS"}` |
| `POST /api/payments/callbacks/alipay` | ✅ 完成 | form-encoded 解析，返回 `"success"` |
| 回调幂等（重放保护） | ✅ 完成 | 已 succeeded 的退款收到重复回调直接返回 200 |
| `provider_refund_no` 唯一索引 | ✅ 确认 | 数据库层已有唯一索引（`index_refunds_on_provider_refund_no`） |
| 退款成功 → 订单状态联动 | ✅ 完成 | `refund → succeeded` + `order → refunded` |
| AuditLog 审计 | ✅ 完成 | 回调成功记录 channel、provider_refund_no 等 |
| `notify_payload` 保存 | ✅ 完成 | 原始回调数据完整存储 |

### 3. Provider 层
| 功能点 | 状态 | 说明 |
|--------|------|------|
| `WechatProvider#create_refund` — Mock 模式 | ✅ 完成 | `WECHAT_MCH_ID` 为空时返回模拟成功数据 |
| `AlipayProvider#create_refund` — Mock 模式 | ✅ 完成 | `ALIPAY_APP_ID` 为空时返回模拟成功数据 |
| `WechatProvider#verify_callback` — Mock 模式 | ✅ 完成 | Mock 模式始终返回 `true` |
| `AlipayProvider#verify_callback` — Mock 模式 | ✅ 完成 | Mock 模式始终返回 `true` |
| `ProviderFactory.for(channel)` | ✅ 已有 | 按 channel 选择 Provider |

---

## ⚠️ 留白功能（待执照后实现）

### 1. WeChat Pay 真实 API 调用
| 留白项 | 位置 | 说明 |
|--------|------|------|
| `create_refund` 真实 HTTP 请求 | `wechat_provider.rb` L42-51 | `POST /v3/refund/domestic/refunds`，需 RSA-SHA256 签名 |
| `verify_callback` 签名验证 | `wechat_provider.rb` L73-86 | RSA-SHA256 + AES-256-GCM 解密 |
| XML 回调解密 | `callbacks_controller.rb` `parse_json_body` | 真实回调为加密 XML，需 AES-256-GCM 解密 |

### 2. Alipay 真实 API 调用
| 留白项 | 位置 | 说明 |
|--------|------|------|
| `create_refund` 真实 HTTP 请求 | `alipay_provider.rb` L41-54 | `alipay.trade.refund`，需 RSA2 签名 |
| `verify_callback` 签名验证 | `alipay_provider.rb` L67-79 | RSA2 (SHA256WithRSA) 验签 |

### 3. 执照后启用步骤
1. 注册微信支付/支付宝商户，获取 `MCH_ID`、`APP_ID`、密钥等
2. 在 `.env.production` 中配置对应环境变量
3. 在 Provider 的 `else` 分支中替换 `err_response` 为真实 API 调用
4. 实现 `verify_callback` 的真实签名验证逻辑
5. 运行 `RAILS_ENV=production bin/rails zeitwerk:check` 确认无误

---

## 测试结果

```
37 examples, 0 failures (0.49s)
```

### ProcessRefundJob Spec（18 例）
- ✅ 幂等性：succeeded/failed 状态跳过，不存在的 refund 不报错
- ✅ Mock — WeChat：状态转换、时间戳、provider_refund_no、订单联动、AuditLog
- ✅ Mock — Alipay：状态转换、provider_refund_no、订单联动
- ✅ AASM 幂等：订单已 refunded 不重复触发
- ✅ 错误分类：不可重试 → failed；可重试 → 抛异常让 Sidekiq 重试
- ✅ STUB 测试：WeChat/Alipay 真实模式返回"pending business license"

### Callback Spec（19 例）
- ✅ WeChat 回调：200 成功、状态转换、订单联动、AuditLog
- ✅ WeChat 重放：幂等返回 200，不重复写 AuditLog
- ✅ WeChat 未知退款号：422、缺少字段：400
- ✅ Alipay 回调：200 "success"、状态转换、订单联动、AuditLog
- ✅ Alipay 重放：幂等返回 200 "success"
- ✅ Alipay 未知退款号：422 "fail"、缺少字段：400 "fail"
- ✅ STUB 测试：Mock 模式签名绕过 + 真实模式返回 false

---

## 文件清单

| 文件 | 状态 | 类别 |
|------|------|------|
| `app/jobs/refunds/process_refund_job.rb` | 修改 | Job |
| `app/services/payments/wechat_provider.rb` | 修改 | Provider |
| `app/services/payments/alipay_provider.rb` | 修改 | Provider |
| `app/services/payments/handle_callback_service.rb` | **新建** | Service |
| `app/controllers/api/payments/callbacks_controller.rb` | **新建** | Controller |
| `config/routes.rb` | 修改 | 路由 |
| `spec/jobs/refunds/process_refund_job_spec.rb` | **新建** | 测试 |
| `spec/requests/api/payments/callbacks_spec.rb` | **新建** | 测试 |
