# 安全测试快速参考

## 🚀 快速开始

### 测试 Devise 账户锁定
```bash
./quick_test_lockable.sh
./check_lockable_status.rb 634264926@qq.com
```

### 测试 Rack::Attack 限流
```bash
./quick_test_rack_attack.sh
tail -f log/development.log | grep 'Rack::Attack'
```

## 🔑 常用命令

| 操作 | 命令 |
|------|------|
| 检查账户状态 | `./check_lockable_status.rb <email>` |
| 解锁账户 | `rails runner "User.find_by(email: 'xxx')&.unlock_access!"` |
| 查看所有锁定账户 | `rails runner "User.where.not(locked_at: nil).pluck(:email)"` |
| 查看限流日志 | `tail -f log/development.log \| grep Rack::Attack` |
| 重置失败次数 | `rails runner "User.find_by(email: 'xxx')&.update(failed_attempts: 0)"` |

## ⚙️ 当前配置

### Devise Lockable
- **最大尝试次数**: 5次
- **锁定时长**: 30分钟
- **解锁方式**: 邮件 + 时间

### Rack::Attack
- **登录限流 (IP)**: 5次/5分钟
- **登录限流 (Email)**: 5次/5分钟
- **全局限流 (IP)**: 300次/分钟

## 📋 测试文件

- `test_security.sh` - 完整测试套件
- `quick_test_lockable.sh` - Devise 快速测试
- `quick_test_rack_attack.sh` - Rack::Attack 快速测试
- `check_lockable_status.rb` - 状态检查工具
- `SECURITY_TESTING.md` - 详细文档
