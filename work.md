周三：微信支付退款真实对接
- 接入微信支付退款 API（v3）：
  - 签名/验签（HMAC-SHA256 / RSA）
  - 幂等处理（同一 refund 多次触发不重复）
  - 错误码映射（可重试 vs 需人工）
Refunds::ProcessRefundJob
- ：调用 
WechatProvider.refund
验收：staging 通过微信沙箱发起一笔退款，返回成功/受理，记录完整 request/response。

---
周四：支付宝退款对接 + 回调处理
- 接入支付宝退款 API：
  - RSA2 签名/验签
  - 幂等与错误处理
- 回调 endpoint：
/api/payments/callback/wechat
- 、
/api/payments/callback/alipay
- 回调幂等：
provider_refund_no
  -  唯一
  - 重放不重复更新
- 成功后联动：
refunds.status = succeeded
orders.status = refunded
验收：模拟/真实回调能把 refund 置为 succeeded，订单联动，审计齐全。

---
周五：订单关键动作后台化
- ActiveAdmin：Orders 增加关键 action（走 service）：
  - 代用户指派商家 
Orders::AssignMerchant
  - （事务锁）
  - 冻结商家/用户后订单限制
- AuditLogs 覆盖上述动作
验收：运营可在后台完成指派商家（正确更新 bids），全过程可追踪。