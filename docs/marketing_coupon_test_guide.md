# 营销工具（优惠券）功能测试文档

## 概述

本文档指导测试 Craftlet 营销工具系统，包含以下功能模块：
- 优惠券模板管理（满减/折扣/兑换码）
- 发放规则（新用户/生日/等级）
- 使用限制（品类/商家/时间）
- 预算控制与告警
- 活动效果分析

---

## 前置条件

```bash
# 1. 运行数据库迁移
bundle exec rails db:migrate

# 2. 启动开发服务器
bundle exec rails server

# 3. 登录 ActiveAdmin 后台
# 地址: http://localhost:3000/admin
```

---

## 一、Admin 后台测试

### 1.1 优惠券模板管理

**访问路径：** `/admin/coupon_templates`（营销工具 → 优惠券模板）

#### 测试用例 T1：创建满减券模板

| 步骤 | 操作 | 预期结果 |
|------|------|----------|
| 1 | 点击「新建 Coupon template」 | 显示创建表单 |
| 2 | 填写名称：`满100减20` | - |
| 3 | 类型选择：`满减券` | - |
| 4 | 面值填写：`20` | - |
| 5 | 最低消费：`100` | - |
| 6 | 总配额：`1000` | - |
| 7 | 预算总额：`20000` | - |
| 8 | 告警阈值：`0.8` | - |
| 9 | 领取后有效天数：`30` | - |
| 10 | 每人限领：`1` | - |
| 11 | 点击「创建 Coupon template」 | 模板创建成功，状态为「草稿」 |

**验证要点：**
- 模板列表显示该模板，配额列显示 `0/1000`
- 预算列显示 `¥0/¥20000`

---

#### 测试用例 T2：创建折扣券模板

| 步骤 | 操作 | 预期结果 |
|------|------|----------|
| 1 | 创建新模板，类型选择「折扣券」 | - |
| 2 | 面值填写：`0.9`（9折） | - |
| 3 | 填写其他必要字段 | - |
| 4 | 提交 | 创建成功 |
| 5 | **尝试填写面值 `1.5`**（超过1） | 验证失败，提示面值必须小于1 |

---

#### 测试用例 T3：创建兑换码模板

| 步骤 | 操作 | 预期结果 |
|------|------|----------|
| 1 | 类型选择「兑换码」，面值填写商品价值 | - |
| 2 | 不设配额限制（留空） | 创建成功 |

---

#### 测试用例 T4：模板启用/停用

| 步骤 | 操作 | 预期结果 |
|------|------|----------|
| 1 | 进入草稿状态的模板详情页 | 显示「启用模板」按钮 |
| 2 | 点击「启用模板」→ 确认 | 状态变更为「启用」，按钮变为「停用模板」 |
| 3 | 点击「停用模板」→ 确认 | 状态变更为「停用」 |

---

### 1.2 手动发放优惠券

**在模板详情页测试：**

| 步骤 | 操作 | 预期结果 |
|------|------|----------|
| 1 | 进入已激活的模板详情页 | - |
| 2 | 通过地址栏调用发放接口：`POST /admin/coupon_templates/:id/issue` + `user_id=1` | 可通过 curl 或表单测试 |
| 3 | 成功时页面提示「优惠券已发放，券码：XXXXXX」 | 12位大写字母数字券码 |
| 4 | 刷新详情页，「最近发放记录」面板显示新券 | 发放来源为「手动发放」 |
| 5 | 进入优惠券列表 `/admin/coupons` | 可看到新发放的优惠券 |

**边界测试：**
- 向已达每人限领上限的用户再次发放 → 提示「已超过每人领取上限」
- 对停用的模板调用发放 → 提示「优惠券模板未激活」
- 配额耗尽时发放 → 提示「发放配额已耗尽」

---

### 1.3 优惠券列表

**访问路径：** `/admin/coupons`（营销工具 → 优惠券）

| 测试点 | 操作 | 预期结果 |
|--------|------|----------|
| 按状态筛选 | 选择「未使用」Scope | 只显示未使用的优惠券 |
| 按模板筛选 | 使用模板过滤器 | 只显示该模板的券 |
| CSV 导出 | 点击「CSV」 | 下载包含所有列的 CSV 文件 |

---

### 1.4 预算告警测试

**准备：** 创建一个配额为 5、告警阈值为 0.8 的模板并激活

| 步骤 | 操作 | 预期结果 |
|------|------|----------|
| 1 | 向5个不同用户各发放1张 | 第4张发放后（80%）触发告警 |
| 2 | 访问 `/admin/coupon_budget_alerts` | 列表显示「待处理」的「配额预警」告警 |
| 3 | 进入告警详情 | 显示当前比例（如 80%）及关联模板 |
| 4 | 点击「标记处理」→ 确认 | 告警状态变更为「已处理」，记录处理人和时间 |
| 5 | 发放第5张（100%） | 触发「配额耗尽」告警 |
| 6 | 批量选中待处理告警 → 批量处理 | 所有选中告警状态变更为「已处理」 |

---

### 1.5 活动效果分析

**访问路径：** `/admin/coupon_analytics`（营销工具 → 活动效果分析）

| 测试点 | 预期内容 |
|--------|----------|
| 整体统计 | 显示总发放量、已使用、未使用、已过期、使用率、总抵扣金额 |
| 模板明细 | 每个模板一行，显示发放数、使用数、使用率、抵扣金额、配额进度、预算进度 |
| 近7日趋势 | 最近7天每天的发放量、使用量、抵扣金额 |
| 待处理告警 | 显示所有待处理告警，提供快速处理入口 |

---

## 二、API 接口测试

### 2.1 获取用户优惠券列表

```bash
# 获取当前用户所有优惠券
GET /api/v1/coupons
Authorization: Bearer <user_jwt_token>

# 只看未使用的
GET /api/v1/coupons?status=unused
```

**预期响应：**
```json
[
  {
    "id": 1,
    "code": "ABC123DEF456",
    "status": "unused",
    "grant_type": "manual",
    "granted_at": "2026-03-30T10:00:00Z",
    "expires_at": "2026-04-29T10:00:00Z",
    "usable": true,
    "template": {
      "id": 1,
      "name": "满100减20",
      "coupon_type": "fixed_amount",
      "face_value": "20.0",
      "min_order_amount": "100.0"
    }
  }
]
```

---

### 2.2 获取可用优惠券（按订单金额筛选）

```bash
# 查看订单金额为150元时可用的优惠券
GET /api/v1/coupons/available?order_amount=150
Authorization: Bearer <user_jwt_token>
```

**测试场景：**
- `order_amount=50`：满100减20券不显示（未达门槛）
- `order_amount=150`：满100减20券显示
- 不传 `order_amount`：返回所有未过期的未使用券

---

### 2.3 兑换码核销

```bash
POST /api/v1/coupons/redeem
Authorization: Bearer <user_jwt_token>
Content-Type: application/json

{"code": "REDEEM123"}
```

**测试场景：**
| 场景 | 预期响应 |
|------|----------|
| 有效兑换码 | 201，返回新发放的优惠券信息 |
| 不传 code | 422，`{"error": "请输入兑换码"}` |
| 无效兑换码 | 422，`{"error": "无效的兑换码"}` |
| 未登录 | 401 Unauthorized |

---

### 2.4 新用户优惠券发放

```bash
# 通常在注册后自动调用
POST /api/v1/coupons/grant_new_user
Authorization: Bearer <user_jwt_token>
```

**前置条件：** 存在启用的、设置了「新用户」发放规则的模板

**预期响应：**
```json
[
  {
    "id": 2,
    "code": "NEWUSER1234",
    "grant_type": "new_user",
    ...
  }
]
```

---

## 三、模型层单元测试要点

可在 Rails console 中验证：

```ruby
# 创建测试模板
tmpl = CouponTemplate.create!(
  name: "测试满减",
  coupon_type: "fixed_amount",
  face_value: 10,
  min_order_amount: 50,
  status: "active",
  total_quota: 3,
  budget_amount: 30,
  budget_alert_threshold: 0.6,
  valid_days: 7,
  per_user_limit: 1,
  grant_rules: {}
)

# 创建测试用户
user = User.first

# 发放券
coupon = tmpl.issue_to!(user)
puts coupon.code        # 12位大写码
puts coupon.expires_at  # 7天后

# 验证配额已更新
tmpl.reload.issued_count   # => 1
tmpl.quota_used_ratio      # => 0.333...

# 计算折扣
coupon.calculate_discount(100)  # => 10（满50减10，100 >= 50）
coupon.calculate_discount(30)   # => 0（30 < 50，不满足门槛）

# 使用优惠券
coupon.use!(order_id: 999, discount_amount: 10)
coupon.reload.status   # => "used"
tmpl.reload.used_amount  # => 10.0

# 验证不可重复使用
coupon.usable?  # => false

# 配额耗尽测试
user2 = User.second
user3 = User.third
tmpl.issue_to!(user2)
tmpl.issue_to!(user3)  # 第3张，触发 60% 告警
# 此时 quota_used_ratio = 1.0，下次 issue_to! 会 raise

# 预算告警检查
CouponBudgetAlert.where(coupon_template: tmpl).pluck(:alert_type, :status)
```

---

## 四、数据库结构验证

```bash
# 确认3张新表存在
bundle exec rails runner "
  puts CouponTemplate.table_name
  puts Coupon.table_name
  puts CouponBudgetAlert.table_name
"
# 输出:
# coupon_templates
# coupons
# coupon_budget_alerts
```

---

## 五、预期的文件清单

实现涉及以下新文件：

| 文件 | 用途 |
|------|------|
| `db/migrate/20260330100001_create_coupon_templates.rb` | 优惠券模板表 |
| `db/migrate/20260330100002_create_coupons.rb` | 优惠券记录表 |
| `db/migrate/20260330100003_create_coupon_budget_alerts.rb` | 预算告警表 |
| `app/models/coupon_template.rb` | 模板模型（含发放逻辑） |
| `app/models/coupon.rb` | 优惠券模型（含核销逻辑） |
| `app/models/coupon_budget_alert.rb` | 告警模型 |
| `app/admin/coupon_templates.rb` | Admin 模板管理界面 |
| `app/admin/coupons.rb` | Admin 优惠券列表界面 |
| `app/admin/coupon_budget_alerts.rb` | Admin 预算告警界面 |
| `app/admin/coupon_analytics.rb` | Admin 活动效果分析页 |
| `app/controllers/api/v1/coupons_controller.rb` | 用户端 API |
| `config/locales/marketing.zh-CN.yml` | 中文翻译 |
| `config/locales/marketing.en.yml` | 英文翻译 |

---

## 六、已知限制与后续可扩展点

1. **使用限制（品类/商家）**：`category_ids` 和 `merchant_ids` 字段已建立，存储为 JSONB 数组。实际校验逻辑需在 `Coupon#calculate_discount` 中加入品类/商家过滤，待品类/商家模型完善后对接。

2. **生日/等级发放**：`grant_rules` 字段已预留 `birthday`、`min_level` 配置，但自动触发逻辑（如定时任务给生日用户发券）需另行实现。

3. **过期处理**：`Coupon.expire_stale!` 方法已实现，需通过 Sidekiq/whenever 配置定时任务每日执行。

4. **与订单系统集成**：`Coupon#use!` 接口已就绪，需在订单支付流程中调用，传入 `order_id` 和实际 `discount_amount`。
