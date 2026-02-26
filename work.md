周四：权限与敏感信息治理
- 身份证号等字段：
  - 展示脱敏（只显示后四位）
  - 仅 risk/super_admin 可查看原文
- ActiveAdmin 菜单与 action 全面权限化
验收：ops 账号无法看到敏感字段与退款审批按钮；risk 账号可以。