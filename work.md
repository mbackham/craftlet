把“关键动作”收口到 Service（为下周真实退款对接铺路）
1. Service Objects 骨架（最少这三个）
- Merchants::Approve / Merchants::Reject
- Users::Suspend / Users::Unsuspend（冻结/解冻）
- Refunds::Approve / Refunds::Reject（本周先做壳：改状态 + 入审计 + enqueue job；下周接聚合退款）
核心要求：ActiveAdmin 的 action 不直接改关键状态，统一调用 service。
2. 任务队列与异步框架（Sidekiq）
- 本地可跑 Sidekiq（连接 Redis）
- 云端也可跑（为下周退款回调/异步退款 job 做准备）
3. 质量收尾
- 给 P0 关键路径加基础测试（最少 model 约束 + service happy path）
- 权限补洞：没有权限的人看不到菜单、点不了按钮、接口也会被拒绝（双层校验）
周五验收标准
- 后台关键审批/上下架/冻结等动作都走 service 且产生 audit
- Sidekiq 在云端可启动（哪怕没有真正 job 逻辑）
- 下周可以直接开始：聚合退款 provider 对接 + 回调幂等落库