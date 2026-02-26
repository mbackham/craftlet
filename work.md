周三：风控规则/事件（先"能记录能处理"）
- migrations：
risk_rules
- 、
risk_events
- 最小规则（2~3 条）：
  - 同一用户短时高频退款申请
  - 同一用户高金额退款
  - 同一商家短时大量竞标/撤回
- 后台可对 risk_event 标记：ignored/processed
验收：触发点能写入 risk_event，后台可查看与处理。