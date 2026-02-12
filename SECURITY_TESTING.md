# 安全功能测试指南

## 📋 概述

本项目实现了两层安全保护：
1. **Rack::Attack 限流** - 防止IP级别的暴力攻击
2. **Devise Lockable** - 防止账户级别的暴力破解

## 🔍 为什么你的原始测试脚本不够充分？

你的原始脚本：
```bash
EMAIL="634264926@qq.com"
for i in {1..5}; do
  curl ... -d "{\"user\":{\"email\":\"$EMAIL\",\"password\":\"wrong_password\"}}"
done
# 然后用不同的邮箱 admin@example.com 测试
```

**问题**：
- ❌ 使用不同邮箱无法验证 **账户锁定** 功能（Devise lockable 是按账户锁定的）
- ❌ 只测试了 5 次，无法确认是 Rack::Attack 限流还是 Devise 锁定
- ❌ 没有验证锁定后使用正确密码的行为

## ✅ 正确的测试方法

### 方案 1: 测试 Devise Lockable（推荐）

```bash
# 1. 运行快速测试
./quick_test_lockable.sh

# 2. 检查账户状态
./check_lockable_status.rb 634264926@qq.com

# 3. 解锁账户
rails runner "User.find_by(email: '634264926@qq.com')&.unlock_access!"
```

**预期结果**：
- 前 5 次：返回 401 Unauthorized，错误信息类似 "Invalid Email or password"
- 第 6 次（正确密码）：返回 401，错误信息包含 "locked" 或 "账户已锁定"

### 方案 2: 测试 Rack::Attack 限流

```bash
# 1. 运行限流测试
./quick_test_rack_attack.sh

# 2. 查看 Rails 日志
tail -f log/development.log | grep 'Rack::Attack'
```

**预期结果**：
- 前 5 次：返回 401 Unauthorized
- 第 6 次：返回 429 Too Many Requests
- 响应包含：`{"error":"请求过于频繁，请稍后再试","retry_after":300}`

### 方案 3: 完整测试（包含所有场景）

```bash
./test_security.sh
```

## 📊 两种保护机制的区别

| 特性 | Rack::Attack | Devise Lockable |
|------|-------------|----------------|
| **触发层级** | 中间件层（IP级别） | 应用层（账户级别） |
| **限制范围** | 同一IP的所有请求 | 单个账户的失败尝试 |
| **触发条件** | 5分钟内5次登录尝试 | 累计5次失败登录 |
| **解除方式** | 等待5分钟（时间窗口） | 等待30分钟 或 邮件解锁 |
| **攻击场景** | 防止分布式撞库 | 防止针对特定账户的暴力破解 |

## 🧪 测试场景详解

### 场景 1: Devise Lockable 触发

```bash
# 准备：确保账户未锁定
./check_lockable_status.rb 634264926@qq.com

# 执行：5次失败尝试
for i in {1..5}; do
  curl -X POST http://localhost:3000/api/v1/users/sign_in \
    -H "Content-Type: application/json" \
    -d '{"user":{"email":"634264926@qq.com","password":"wrong"}}'
done

# 验证：使用正确密码（应该失败）
curl -X POST http://localhost:3000/api/v1/users/sign_in \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"634264926@qq.com","password":"correct_password"}}'

# 检查：数据库状态
rails runner "u = User.find_by(email: '634264926@qq.com'); puts \"Locked: #{u.access_locked?}, Attempts: #{u.failed_attempts}\""
```

**预期输出**：
```
Locked: true, Attempts: 5
```

### 场景 2: Rack::Attack 触发

```bash
# 使用不同邮箱快速请求（避免 Devise lockable 干扰）
for i in {1..6}; do
  curl -X POST http://localhost:3000/api/v1/users/sign_in \
    -H "Content-Type: application/json" \
    -d "{\"user\":{\"email\":\"test$i@example.com\",\"password\":\"wrong\"}}"
done
```

**预期第6次响应**：
```json
{
  "error": "请求过于频繁，请稍后再试",
  "retry_after": 300
}
```

### 场景 3: 同时触发两种保护

实际生产环境中，两种保护会同时生效：
1. **第1-5次尝试**：正常处理（但累计失败次数）
2. **第5次后**：Devise 锁定账户
3. **继续尝试**：可能触发 Rack::Attack IP 限流

## 🛠️ 辅助命令

### 查看所有锁定的账户
```bash
rails runner "User.where.not(locked_at: nil).each { |u| puts \"#{u.email} - #{u.locked_at}\" }"
```

### 批量解锁所有账户
```bash
rails runner "User.where.not(locked_at: nil).find_each(&:unlock_access!)"
```

### 查看 Rack::Attack 限流日志
```bash
tail -f log/development.log | grep 'Rack::Attack'
```

### 清除 Rack::Attack 缓存（重启服务器）
```bash
# 在开发环境，Rack::Attack 使用 MemoryStore
# 重启 Rails 服务器会清除所有限流记录
```

## 📝 验证清单

- [ ] 5次失败登录后，账户被锁定
- [ ] 锁定后使用正确密码仍无法登录
- [ ] 数据库中 `locked_at` 字段有值
- [ ] `failed_attempts` 字段为 5
- [ ] 30分钟后账户自动解锁（如果 unlock_strategy 包含 :time）
- [ ] 同一IP 5分钟内超过5次请求返回 429
- [ ] Rack::Attack 触发时 Rails 日志有警告信息

## 🚨 注意事项

1. **测试前检查**：
   - 确保 Rails 服务器正在运行
   - 确保测试邮箱存在于数据库中
   - 确保账户未被锁定

2. **测试后清理**：
   ```bash
   # 解锁测试账户
   ./check_lockable_status.rb 634264926@qq.com
   
   # 或使用命令行
   rails runner "User.find_by(email: '634264926@qq.com')&.unlock_access!"
   ```

3. **生产环境**：
   - Rack::Attack 应使用 Redis 作为缓存后端（不是 MemoryStore）
   - 确保配置了邮件发送功能（用于发送解锁邮件）
   - 考虑添加验证码（CAPTCHA）作为额外保护层

## 📚 相关配置文件

- `config/initializers/rack_attack.rb` - Rack::Attack 配置
- `config/initializers/devise.rb` - Devise 配置（lockable相关）
- `db/migrate/*_add_lockable_trackable_to_users.rb` - 数据库迁移
- `app/models/user.rb` - User 模型（包含 lockable 模块）
