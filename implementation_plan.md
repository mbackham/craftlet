# 对账系统 (Financial Reconciliation System) 实施计划

## 概述与可行性分析
根据当前的 `Payment`, `Order` 和 `Refund` 表结构，构建一个标准的三方对账系统完全可行。
由于支付宝与微信支付目前的接口凭证尚在申请中，因此我们首先搭建一个**可扩展的对账架构**。
系统将主要以外部上传的「银行流水记录 / 支付渠道账单」为驱动，通过解析账单中的交易号(Transaction ID) / 订单号(Order No) 与系统内的数据进行对账。

### 关于支付宝与微信支付的说明
在代码结构中，会预留针对如 `Reconciliation::Channels::Alipay` 和 `Reconciliation::Channels::Wechat` 等处理器的存根设计（留白处理）。当相关资质申请通过后，只需要补充定时拉取账单的 API 请求并写入 `BankStatement` 表中，即可复用已有的对账核心逻辑。

## User Review Required
> [!NOTE]
> 请确认以下对账差异处理的状态流转是否符合实际财务操作？
> - 未处理 (pending) -> 已认领 (claimed) -> 财务已调平 (adjusted) -> 无需处理/忽略 (ignored)

## Proposed Changes

### 1. Database & Models
---
新增三个核心表来支撑对账体系：
#### [NEW] `BankStatement` 
用于记录每一次导入的对账单文件（无论是手动导入的银行流水，还是未来定时任务拉取的微信/支付宝账单）。
包含字段：`channel` (渠道: bank, alipay, wechat), `statement_date` (账单日期), `status` (处理状态), `file` (原始文件附件)。

#### [NEW] `ReconciliationBatch` 
用于记录一次对账任务的执行批次，通常每天执行一次。
包含字段：`target_date` (对账目标日期), `status` (对账状态: processing, completed, failed), `total_count` (总笔数), `matched_count` (平账笔数), `mismatched_count` (异常笔数)。

#### [NEW] `ReconciliationDetail` 
对账明细及差异记录。这是财务工作的核心表。
包含字段：
- `reconciliation_batch_id`
- `transaction_no` (交易流水号)
- `order_no` (商户订单号)
- `reconciliation_type` (对账类型: payment, refund)
- `system_amount` (系统金额)
- `statement_amount` (账单金额)
- `match_status` (匹配状态: matched 一致, amount_mismatch 金额不符, missing_in_system 系统漏单, missing_in_statement 渠道漏单)
- `process_status` (处理状态: pending 未处理, claimed 已认领, adjusted 已调账, ignored 忽略)
- `handler_admin_id` (处理人)
- `adjustment_reason` (调账原因备注)

### 2. Services 核心逻辑
---
#### [NEW] `app/services/reconciliation/statement_parser.rb`
接收 `BankStatement` 实例，根据其 `channel` 决定解析方式（读取 CSV/Excel），并将数据行作为标准格式返回供对账使用。

#### [NEW] `app/services/reconciliation/matcher_service.rb`
执行单条记录的比较逻辑。传入账单行数据字典与内部 `Payment`/`Refund` 进行金额比较。

#### [NEW] `app/services/reconciliation/batch_processor.rb`
总控服务。找出特定日期下所有渠道的账单明细，及系统内的支付退款记录，执行双向比对并生成 `ReconciliationDetail` 记录。更新批次统计。

#### [NEW] `app/services/reconciliation/channels/base.rb`
定义渠道适配器接口。目前会包含一个可运行的 `BankCsv` 处理器，并为支付宝和微信创建留白说明的代码文件。

### 3. 后台管理 (ActiveAdmin)
---
#### [NEW] `app/admin/bank_statements.rb`
允许运营/财务上传特定日期的对账单文件。

#### [NEW] `app/admin/reconciliation_batches.rb`
展示每次对账的结果统计情况（例如昨日对账成功多少笔，差异多少笔），并提供按钮“重新执行对账”。

#### [NEW] `app/admin/reconciliation_details.rb`
**差异处理工作台**。列出所有 `match_status` 不为 `matched` 的记录。
提供 Action 操作：
- 认领 (Claim)：将当前登录的 AdminUser 设置为 handler。
- 调账平账 (Adjust)：弹出表单要求填写调账原因并提交。
- 忽略 (Ignore)：标记此记录无需处理。
并配置特定的权限（仅具有财务权限的角色可操作）。

#### [NEW] `app/admin/reconciliation_dashboard.rb` (集成到现有 Dashboard)
展示近7天对账差异走势图或今日待处理差异统计卡片。

## Verification Plan

### Automated Tests
- 为核心匹配逻辑编写单元测试 (例如测试金额不一致时是否正确产生 `amount_mismatch` 状态)。
- 使用 rspec 测试批处理服务是否正确生成不同情景下的差异记录。

### Manual Verification
1. 登录 Admin 系统并打开预生成的假数据（提供快速测试用的 CSV 账单）。
2. 在后台上传该 CSV 文件，并点击“执行对账”。
3. 到“对账明细”列表查看所产生的各种类型差异数据（包括系统漏单、账单漏单、金额不符）。
4. 模拟财务人员进行“认领”操作和“标记已调账”操作。
