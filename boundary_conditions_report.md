# 边界条件修复 — 回归测试报告

**项目**：Craftlet Admin  
**日期**：2026-03-05  
**关联工作项**：`work.md` — 周四：回归测试与修复（修复边界条件）  
**测试范围**：重复回调 · 重复点击 approve · 并发指派

---

## 代码审查结论

### ✅ BC-1：重复回调悲观锁（`handle_callback_service.rb`）

**修复策略**：用 `refund.with_lock { … }` 替换原来的 `refund.reload`，在数据库行级加 `SELECT FOR UPDATE` 锁。

**代码路径**：`app/services/payments/handle_callback_service.rb: process_callback!`

**双重防护机制**：
1. **外层（第 39 行）**：进入 `with_lock` 之前先检查 `status == "succeeded"`，快速幂等返回。
2. **内层（第 81 行）**：在锁内再次 double-check，彻底杜绝并发穿透。

**代码审查结论**：✅ 逻辑正确，双重检查到位，无遗漏风险。

---

### ✅ BC-2：退款操作表单连点保护（`refunds.rb`）

**修复策略**：所有 Inline Form 的 `<form>` 标签注入 `onsubmit` JS，首次点击立即置灰按钮并展示"处理中..."。

**覆盖的三个 member action**：

| 操作 | 文件行 | onsubmit 注入 |
|------|--------|----------------|
| `approve` (PUT) | ~273 | ✅ 已注入 |
| `reject` (PUT) | ~340 | ✅ 已注入 |
| `retry_refund` (PUT) | ~415 | ✅ 已注入 |

**服务层兜底（`approve_service.rb`）**：
- 使用 `refund.lock!`（`SELECT FOR UPDATE`）+事务防并发。
- `validate!` 在锁后调用，`refund` 返回 `@refund`（已重新赋值为锁定后的行），状态检查基于最新数据。✅

**代码审查结论**：✅ 前端 JS 防止 UX 层连击；后端 `lock!` + 事务为最终保障，形成双层防线。

---

### ✅ BC-3：工单并发指派悲观锁（`tickets.rb`）

**修复策略**：在 `assign` PUT 分支中，整个赋值 + AASM 状态转换 + 审计日志写入均包裹在 `@ticket.with_lock { … }` 内部。

**本次额外修复（Bug Fix）**：

> **原始代码**（有缺陷）：  
> `redirect_to … notice: "已指派给 #{AdminUser.find(params[:assignee_id]).email}"`  
> 锁内查询到的 `admin` 对象作用域在 block 内，`with_lock` 结束后重复发起 `AdminUser.find`——多一次 IO，且理论上在高并发边界上 `params[:assignee_id]` 的对象可能已失效。
>
> **修复后**：在 `with_lock` 块内捕获 `assignee_email` 局部变量，redirect 直接引用，无冗余查询。

**`assign.html.erb` 补充修复（Bug Fix）**：

> **原始代码**（有缺陷）：  
> `form_tag assign_admin_ticket_path(@ticket), method: :put do`  
> 无任何连点防护，用户双击"确认指派"会提交两次请求。
>
> **修复后**：加入 `onsubmit` 守卫，与退款表单保持一致：  
> ```
> onsubmit="this.querySelector('[type=submit]').disabled=true; this.querySelector('[type=submit]').value='处理中...';"
> ```

**代码审查结论**：✅ `with_lock` 块覆盖完整事务范围；两处衍生 Bug 已修复。

---

## 回归测试用例

### [BC-1] 重复回调 — 悲观锁保护

**前置条件**：一个退款记录处于 `pending` 状态，且存在 `provider_refund_no`。

| # | 操作步骤 | 预期结果 |
|---|----------|----------|
| 1 | 向 `/callbacks/wechat` 发送一次成功回调（`provider_refund_no: WXR_001`） | 退款状态变为 `succeeded`，AuditLog 写入 `callback_refund_succeeded` |
| 2 | **立即**再次发送相同 payload 的回调（模拟网关重试） | 返回 HTTP 200，`replayed?` 为 true，不产生新 AuditLog，退款仍为 `succeeded` |
| 3 | 并发模拟：Rails console 多线程同时调用 `HandleCallbackService.new(…).call` | 其中一个成功，其余均返回 `replayed: true`；数据仅更新一次 |

**验证命令（Console）**：
```ruby
# 验证幂等
r = Refund.find_by(provider_refund_no: "WXR_001")
r.status   # => "succeeded"
AuditLog.where(target: r, action: "callback_refund_succeeded").count  # => 1（无论多少次回调）
```

---

### [BC-2] 重复点击 Approve — 前端 JS 防连击

**前置条件**：一个退款状态为 `init`，且登录用户具有 `refund:approve` 权限。

| # | 操作步骤 | 预期结果 |
|---|----------|----------|
| 1 | 进入退款详情页，点击"审批通过"链接 | 跳转至确认页（GET 表单页） |
| 2 | 填写操作备注；点击"确认审批通过**一次**" | 按钮立刻变灰显示"处理中..."；正常提交；退款变为 `pending` |
| 3 | 填写备注后**快速连击两次**"确认审批通过" | 第一次点击后按钮即被禁用，第二次点击无效；仅发出一次 PUT 请求 |
| 4 | 对状态已为 `pending`/`succeeded` 的退款直接访问 `approve` URL | 重定向回详情页并展示 Alert："当前状态不允许审批" |

**验证命令（Console）**：
```ruby
# 验证只有一条 approve AuditLog
AuditLog.where(target_type: "Refund", target_id: refund.id, action: "approve").count  # => 1
```

---

### [BC-2b] 重复点击 Reject

| # | 操作步骤 | 预期结果 |
|---|----------|----------|
| 1 | 进入退款详情页，点击"拒绝退款" | 跳转至拒绝原因表单页 |
| 2 | 填写原因；快速连击两次"确认拒绝" | 仅第一次提交有效；按钮立即置灰；退款变为 `failed` |

---

### [BC-2c] 重复点击 Retry Refund

| # | 操作步骤 | 预期结果 |
|---|----------|----------|
| 1 | 进入状态为 `failed` 的退款详情页，点击"重试退款" | 跳转至重试确认表单页 |
| 2 | 填写备注；快速连击两次"确认重试" | 仅第一次提交有效；按钮立即置灰；后端触发 `RetryRefundService` |

---

### [BC-3] 并发指派工单 — 悲观锁 + 无冗余查询

**前置条件**：一个工单状态为 `open`，登录用户具有 `ticket:manage` 权限。

| # | 操作步骤 | 预期结果 |
|---|----------|----------|
| 1 | 进入工单详情页，点击"指派处理人" | 渲染 assign 表单，下拉列表展示所有管理员邮箱 |
| 2 | 选择一位管理员，点击"确认指派" | 工单 `assignee_id` 被更新，状态变为 `assigned`，AuditLog 写入 `ticket_assign`；页面 notice 显示正确的邮箱地址 |
| 3 | 快速连击"确认指派"两次 | 按钮立即置灰显示"处理中..."；仅发出一次 PUT 请求（JS 保护） |
| 4 | 模拟并发：Rails console 两个线程同时调用指派逻辑 | `with_lock` 串行化并发请求；数据库中 `assignee_id` 只有一个最终值，无脏写 |

**验证命令（Console）**：
```ruby
t = Ticket.find(ticket_id)
t.assignee&.email       # => 被指派管理员的邮箱
t.status                # => "assigned"
AuditLog.where(target: t, action: "ticket_assign").count  # => 1（无论并发多少次）
```

---

## 部署前检查清单

```bash
# 1. Zeitwerk 一致性检查
RAILS_ENV=production bin/rails zeitwerk:check

# 2. 应用启动检查
RAILS_ENV=production bin/rails runner 'puts :boot_ok'
```

---

## 修复文件汇总

| 文件 | 修复类型 | 状态 |
|------|----------|------|
| `app/services/payments/handle_callback_service.rb` | 并发重复回调 → `with_lock` 双重检查 | ✅ 已修复 |
| `app/services/refunds/approve_service.rb` | `lock!` 防止并发重复审批 | ✅ 已确认正确 |
| `app/admin/refunds.rb` | Approve/Reject/Retry 表单 JS 置灰防连击 | ✅ 已修复 |
| `app/admin/tickets.rb` | `with_lock` 串行并发指派 + 消除锁后冗余查询 | ✅ 已修复 |
| `app/views/admin/tickets/assign.html.erb` | 指派表单 JS 置灰防连击 | ✅ 已修复（本次新增） |
