周二：退款申请与审批链路（后台）
- ActiveAdmin：Refunds 列表/详情/筛选（状态、金额、订单、用户、时间）
- 风控/运营权限：谁能 approve/reject
Refunds::ApproveService
-  / 
Refunds::RejectService
-  完善（已有骨架，补充队列幂等）
验收：后台可对某笔 refund 执行 approve/reject，产生 audit，状态正确变化到 pending/failed。