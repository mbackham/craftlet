# 🛡️ 安全功能测试工具集

本目录包含完整的安全功能测试工具和文档。

## 📁 文件列表

### 🔧 测试脚本

| 文件名 | 用途 | 运行方式 |
|--------|------|----------|
| `quick_test_lockable.sh` | **快速测试 Devise 账户锁定** | `./quick_test_lockable.sh` |
| `quick_test_rack_attack.sh` | 快速测试 Rack::Attack IP 限流 | `./quick_test_rack_attack.sh` |
| `test_security.sh` | 完整安全测试套件 | `./test_security.sh` |
| `verify_mailer_fix.sh` | 验证邮件配置修复 | `./verify_mailer_fix.sh` |
| `check_lockable_status.rb` | 🔍 交互式账户状态检查工具 | `./check_lockable_status.rb <email>` |

### 📚 文档

| 文件名 | 内容 |
|--------|------|
| `SECURITY_TEST_RESULTS.md` | **✅ 测试结果总结** |
| `SECURITY_TESTING.md` | 详细测试指南和方法论 |
| `SECURITY_QUICK_REF.md` | 快速参考卡片 |

## 🚀 快速开始

### 1. 测试 Devise 账户锁定（推荐）

```bash
# 运行测试
./quick_test_lockable.sh

# 检查账户状态
./check_lockable_status.rb 634264926@qq.com

# 解锁账户
rails runner "User.find_by(email: '634264926@qq.com')&.unlock_access!"
```

### 2. 测试 Rack::Attack 限流

```bash
# 运行测试
./quick_test_rack_attack.sh

# 查看限流日志
tail -f log/development.log | grep 'Rack::Attack'
```

### 3. 验证邮件配置

```bash
# 运行验证（会自动创建和清理测试账户）
./verify_mailer_fix.sh
```

## ✅ 测试结果

**两个核心安全功能已通过测试！**

- ✅ **Devise Lockable**: 5次失败后成功锁定账户
- ✅ **Rack::Attack**: IP 限流正常工作，返回 429
- ✅ **邮件配置**: 已修复，解锁邮件正常发送

详细结果请查看：[SECURITY_TEST_RESULTS.md](./SECURITY_TEST_RESULTS.md)

## ⚙️ 当前配置

### Devise Lockable
- **最大尝试次数**: 5 次
- **锁定时长**: 30 分钟  
- **解锁方式**: 邮件 + 时间（both）

### Rack::Attack  
- **登录限流 (IP)**: 5次 / 5分钟
- **登录限流 (Email)**: 5次 / 5分钟
- **全局限流 (IP)**: 300次 / 分钟

## 🔑 常用命令

```bash
# 检查账户状态
./check_lockable_status.rb <email>

# 解锁指定账户
rails runner "User.find_by(email: '<email>')&.unlock_access!"

# 查看所有锁定账户
rails runner "User.where.not(locked_at: nil).pluck(:email, :locked_at)"

# 批量解锁所有账户
rails runner "User.where.not(locked_at: nil).find_each(&:unlock_access!)"

# 查看限流日志
tail -f log/development.log | grep 'Rack::Attack'

# 重启服务器（清除 Rack::Attack 内存缓存）
# Ctrl+C 停止，然后重新启动
```

## 🐛 问题排查

### 问题1: HTTP 状态码为 000

**原因**: Rails 服务器未运行

**解决**:
```bash
rails server -b 0.0.0.0 -p 3000
```

### 问题2: ArgumentError - Missing host

**原因**: 邮件配置缺失

**解决**: 已在 `config/environments/development.rb` 中配置
```ruby
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
```

### 问题3: jq: command not found

**原因**: 测试脚本依赖 jq（已移除）

**状态**: ✅ 已修复，脚本不再依赖 jq

## 📖 详细文档

- 📊 [测试结果总结](./SECURITY_TEST_RESULTS.md) - 完整的测试过程和结果分析
- 📚 [测试指南](./SECURITY_TESTING.md) - 详细的测试方法和场景
- 📋 [快速参考](./SECURITY_QUICK_REF.md) - 常用命令速查表

## 🎯 原始问题解答

你最初问的测试脚本存在问题：

```bash
EMAIL="634264926@qq.com"
for i in {1..5}; do
  # 测试 634264926@qq.com 失败5次
done
# 然后用 admin@example.com 测试  ← 问题在这里！
```

**问题**：
- ❌ Devise Lockable 是**按账户锁定**的
- ❌ 你测试了 `634264926@qq.com` 5次失败，然后用 `admin@example.com` 登录
- ❌ 这是两个不同的账户，无法验证锁定功能

**正确做法**：
- ✅ 对同一账户失败5次
- ✅ 然后用**同一账户**的正确密码尝试登录
- ✅ 预期：即使密码正确也应该被拒绝（账户已锁定）

详见：`quick_test_lockable.sh`

## 🚀 下一步

生产环境部署前请配置：

1. **邮件服务器**（`.env.production`）:
   ```bash
   MAILER_HOST=your-domain.com
   SMTP_ADDRESS=smtp.gmail.com
   SMTP_PORT=587
   SMTP_USERNAME=your-email@gmail.com
   SMTP_PASSWORD=your-app-password
   ```

2. **Redis**（用于 Rack::Attack 缓存）:
   ```bash
   REDIS_URL=redis://localhost:6379/1
   ```

3. **测试邮件发送**:
   ```bash
   rails console
   > User.first.send_unlock_instructions
   ```

---

**Happy Testing! 🎉**
