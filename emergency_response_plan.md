# 应急预案与数据修复指南

本文档为 Craftlet 平台生产环境（Production）紧急故障处理指南（Playbook）。主要覆盖支付链路、回调链路以及底层数据异常的手动修复路径。

**⚠️ 重要警告**：
- 执行本预案中“数据修复路径”提供的 Rails Console 命令前，**必须**获得 Tech Lead 或系统管理员的明确授权。
- 所有通过 Console 进行的状态变更不会自动生成常规的系统审计日志（AuditLog），请务必通过内部工单或协作软件记录执行的命令和缘由。

---

## 1. 退款异常处理 (Refund Anomalies)

### 1.1 场景：退款停留在 `pending` 状态迟迟未成功
**现象**：运营已审批通过退款，但状态卡在处理中（`pending`），且微信/支付宝等渠道未见实际退款。
**可能原因**：异步队列（Sidekiq）阻塞或崩溃；支付网关响应极度缓慢但未回调。
**应急处理**：
1. **检查 Sidekiq 日志**：检查 `Refunds::ProcessRefundJob` 是否报错堆积或队列堵塞。
2. **人工查询网关状态**：通过第三方商户平台（如微信支付商户中心）确认该笔 `provider_refund_no` 的真实退款状态。
3. **安全操作**：若确认为网络超时未送达网关，可从后台查看该记录并让开发干预；切勿盲目通过控制台强行改状态重试。

### 1.2 场景：退款状态变为 `failed`
**现象**：由于余额不足、参数错误或网络问题，后台退款记录显示为 `failed`。
**预案指引**：
1. **查看后台详情**：进入 ActiveAdmin Refund 详情页，查看 **“第三方响应代码 (Third-party error code)”** 及 **“系统失败原因”**。
2. **补救操作**：
   - 业务类错误（如：商户余额不足）：联系财务充值后，在后台页面直接点击 **“重试退款 (Retry Refund)”**。系统会重新向支付网关发起请求。
   - 严重参数错误：需排查系统逻辑，不可盲目重试。

### 1.3 场景：意外生成了双重退款（极小概率）
**现象**：由于极端并发或其他网关原因导致了双重审批（此漏洞目前已通过悲观锁 `refund.with_lock` 及防连击前端机制彻底封堵，概率极低）。
**修复路径**：
1. 立即联系财务端或第三方通道提单拦截。
2. 核对 `AuditLog` 确认操作者、时间、IP 并追查访问流量来源。

---

## 2. 支付回调异常 (Callback Anomalies)

### 2.1 场景：客户已付款/退款，但系统状态未更新（丢回调）
**现象**：用户在端侧已经扣款，或第三方通道已显示退款成功，但系统内的 Order/Refund 仍处于未付款或 `pending` 状态。
**可能原因**：网关回调请求被 Nginx/防火墙拦截拦截；或回调期间数据库不可用。
**修复路径 (Rails Console 主动查单/推状态)**：

如果当前没有自动化主动查单定时任务，需通过 Console 手动执行回调逻辑：
```ruby
# 进入生产环境控制台
RAILS_ENV=production bin/rails c

# 根据业务拿到的网关单号，手动调用回调处理服务（以退款为例）
service = Payments::HandleCallbackService.new(
  channel: "wechat",
  provider_refund_no: "WXR_XXX_XXX",
  notify_payload: { "manual_sync": true, "reason": "Missing callback" }
).call

if service.success?
  puts "修复成功！"
elsif service.replayed?
  puts "该单据其实已经成功了（幂等拦截）。"
else
  puts "修复失败：#{service.error}"
end
```

### 2.2 场景：遭遇疯狂的重试回调风暴 (Callback Storm)
**现象**：支付网关因无响应连续疯狂推送回调，导致日志/数据库压力激增。
**预案指引**：
- 系统 `HandleCallbackService` 首行已有高速防穿透拦截（若是已处理单据会立刻抛弃并返回 200）。
- **日志抑制**：若依然消耗过多 IO，可在 Nginx 层面针对该高频请求的 URI 配置临时限流（Rate Limit）或让上游暂时停止推送。

---

## 3. 工单并发修改与数据修复路径

### 3.1 场景：工单状态异常被卡住 
**现象**：在非常规操作或数据迁移中，工单的状态丢失或无法在后台界面继续流转。
**修复路径**：
```ruby
# 进入生产环境控制台
RAILS_ENV=production bin/rails c

ticket = Ticket.find_by(ticket_no: "TCK_123456")

# 强制重置状态为 open，使得可以重新分派接单
ticket.update_columns(status: "open", assignee_id: nil)

# 或者强制标记为解决并补齐审计日志（推荐做法）
ticket.with_lock do
  ticket.resolved_at = Time.current
  ticket.status = "resolved"
  ticket.save(validate: false)
  
  AuditLog.create!(
    target: ticket,
    action: "manual_data_fix",
    actor_id: "system",
    metadata: { reason: "Fixing stuck status from ticket #999" }
  )
end
```
## 4. 常见问题排查与命令摘要
| 操作场景 | 工具/命令 | 说明 |
|----------|-----------|------|
| **重启应用服务器** | `sudo systemctl restart puma` | 重启 Rails Puma 进程，解决内存泄漏或致命卡死 |
| **启动/验证健康度** | `RAILS_ENV=production bin/rails runner 'puts :boot_ok'` | 检查 Zeitwerk 及常量环境是否良好，返回 `boot_ok` 即证明正常 |
| **排查 Nginx 错误** | `tail -f /var/log/nginx/error.log` | 排查 502/504 等网关报错 |
| **排查系统错误** | `tail -f log/production.log \| grep -A 5 "FATAL"` | 实时追踪报错堆栈 |
