# 订单关键动作后台化 — 验收文档

> 生成时间: 2026-02-25

---

## ✅ 已完成功能

### 1. Orders::AssignMerchantService（指派商家）
| 功能点 | 状态 | 说明 |
|--------|------|------|
| 事务悲观锁 | ✅ | `order.lock!` 防并发指派 |
| merchant_id 更新 | ✅ | UUID 格式，写入 `orders.merchant_id` |
| 创建 accepted Bid | ✅ | 为指派商家创建记录 |
| 拒绝其他 pending Bids | ✅ | 批量 → `rejected` |
| AASM 状态转换 | ✅ | `paid → accepted` |
| AuditLog 审计 | ✅ | 记录 before/after 及 merchant_email |

### 2. 冻结限制
| 校验项 | 状态 | 说明 |
|--------|------|------|
| 商家用户 disabled | ✅ 拒绝 | `User.status != 'active'` |
| MerchantProfile 未 approved | ✅ 拒绝 | 含 pending/rejected/suspended |
| 订单状态非 paid | ✅ 拒绝 | 覆盖 created/producing/delivered/completed/canceled/refunded |
| 自我指派 | ✅ 拒绝 | `customer_id == merchant_uuid` |
| AASM guard | ✅ | `accept` 事件增加 `merchant_active?` 守卫 |

### 3. ActiveAdmin UI
| 功能点 | 状态 | 说明 |
|--------|------|------|
| "指派商家"按钮 | ✅ | 仅 `paid` 状态订单 show 页面可见 |
| 商家选择表单 | ✅ | 下拉：active + approved + merchant 角色 |
| 确认/取消操作 | ✅ | 含 confirm 对话框 |

---

## 测试结果

```
17 examples, 0 failures (0.37s)
```

### 逐项验证命令

```bash
# 全量
bundle exec rspec spec/services/orders/assign_merchant_service_spec.rb --format documentation

# 成功路径
bundle exec rspec spec/services/orders/assign_merchant_service_spec.rb -e "成功指派商家" --format documentation

# 冻结限制
bundle exec rspec spec/services/orders/assign_merchant_service_spec.rb -e "冻结" --format documentation

# 状态限制
bundle exec rspec spec/services/orders/assign_merchant_service_spec.rb -e "订单状态不允许" --format documentation

# 自我指派
bundle exec rspec spec/services/orders/assign_merchant_service_spec.rb -e "自我指派" --format documentation
```

---

## 文件清单

| 文件 | 状态 | 类别 |
|------|------|------|
| `app/services/orders/assign_merchant_service.rb` | **新建** | Service |
| `app/models/order.rb` | 修改 | AASM guard + merchant_active? |
| `app/admin/orders.rb` | 修改 | assign_merchant action + 按钮 |
| `app/views/admin/orders/assign_merchant.html.erb` | **新建** | View |
| `spec/services/orders/assign_merchant_service_spec.rb` | **新建** | 测试 |
