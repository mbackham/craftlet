# 工单系统验收文档 — TICKET_SYSTEM

> 生成时间: 2026-02-25

---

## ✅ 已完成功能

### 1. 数据模型
| 表 | 字段 | 说明 |
|---|------|------|
| `tickets` | ticket_no, subject, description, category, priority, status, creator_id/type, assignee_id, order_id | AASM 状态机，唯一 ticket_no |
| `ticket_messages` | ticket_id, sender_id/type, content, internal | 支持内部备注 |
| `ticket_attachments` | ticket_message_id, file_name, file_type, file_size, oss_key, url | OSS 链接先行 |

### 2. AASM 状态流转
```
open → assigned → in_progress → resolved → closed
  ↑                                ↓         ↓
  └──────────── reopen ────────────┘─────────┘
```

### 3. ActiveAdmin 功能
| 功能 | 状态 | 说明 |
|------|------|------|
| 工单列表 | ✅ | 优先级/状态颜色标签、分类筛选、分 scope |
| 工单详情 | ✅ | 信息面板 + 沟通记录时间线 + 附件展示 |
| 创建工单 | ✅ | 主题/描述/分类/优先级 |
| 指派处理人 | ✅ | 下拉选择管理员 + AuditLog |
| 开始处理 | ✅ | assigned → in_progress + AuditLog |
| 标记解决 | ✅ | → resolved + AuditLog |
| 关闭工单 | ✅ | → closed + AuditLog |
| 重新打开 | ✅ | resolved/closed → open + AuditLog |
| 回复工单 | ✅ | 支持内部备注（仅运营可见） |
| 关联订单 | ✅ | show 页面展示关联订单信息 |

### 4. AuditLog 覆盖
- `ticket_create` / `ticket_assign` / `ticket_start_work` / `ticket_resolve` / `ticket_close` / `ticket_reopen` / `ticket_reply`

---

## 测试结果

```
25 examples, 0 failures (0.19s)
```

### 逐项验证命令

```bash
# 全量
bundle exec rspec spec/models/ticket_spec.rb --format documentation

# 验证
bundle exec rspec spec/models/ticket_spec.rb -e "validations" --format documentation

# AASM 状态流转
bundle exec rspec spec/models/ticket_spec.rb -e "AASM" --format documentation

# 关联
bundle exec rspec spec/models/ticket_spec.rb -e "associations" --format documentation

# 消息 & 附件
bundle exec rspec spec/models/ticket_spec.rb -e "TicketMessage" --format documentation
bundle exec rspec spec/models/ticket_spec.rb -e "TicketAttachment" --format documentation
```

---

## 文件清单

| 文件 | 状态 |
|------|------|
| `db/migrate/20260225080000_create_ticket_system.rb` | **新建** |
| `app/models/ticket.rb` | **新建** |
| `app/models/ticket_message.rb` | **新建** |
| `app/models/ticket_attachment.rb` | **新建** |
| `app/admin/tickets.rb` | **新建** |
| `app/views/admin/tickets/assign.html.erb` | **新建** |
| `app/views/admin/tickets/reply.html.erb` | **新建** |
| `spec/models/ticket_spec.rb` | **新建** |
