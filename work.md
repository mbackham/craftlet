商家入驻审批（字段齐全 + 流程跑通 + OSS 资料位）
1. DB migrations（商家入驻相关）
- merchants（含 status：submitted/approved/rejected/suspended）
- merchant_kyc_profiles（营业执照号、法人身份证、开户地址等）
- merchant_documents（doc_type、oss_key/url、状态）
- merchant_approvals（审批流水：approved/rejected、comment、actor）
 后台商家列表页面（筛选、搜索）
 后台商家详情页面（查看资料）
 审核操作（批准/拒绝 + 原因）
 审核历史记录（ReviewLog）
 审核通知（邮件/站内信）
 API：商家查询审核状态
身份证号等敏感字段：本周先保证“能存、能脱敏展示”，加密可下周加强（但至少做脱敏与权限控制）。
2. ActiveAdmin：Merchants 审批页面
- Merchant 列表：按 status 筛选
- Merchant 详情：展示 kyc profile + documents（OSS 链接预览/下载）
- 两个关键 action：
  - Approve（写 approvals + audit + merchants.status=approved）
  - Reject（写 reason + approvals + audit + merchants.status=rejected）
work验收标准
- 商家资料能录入（哪怕先通过 rails console/seed 造数据）
- 后台可以审批通过/驳回，并可追溯审批历史与审计日志
后台管理商家 完整 CRUD
 审核状态机（pending → approved/rejected）
 后台审核页面（可批量操作）
 API 接口