# Craftlet 云服务器部署指南

## 服务器信息
- IP: 154.219.107.73
- 域名: komaprogram.xyz
- 用户: root

---

## 一、服务器环境准备

### 1. 登录服务器
```bash
ssh root@154.219.107.73
# 或
ssh root@komaprogram.xyz
```

### 2. 安装基础依赖
```bash
# 更新系统
apt update && apt upgrade -y

# 安装必要工具
apt install -y curl git build-essential libssl-dev libreadline-dev zlib1g-dev \
  libpq-dev postgresql postgresql-contrib redis-server nginx

# 安装 Node.js (Rails 7 需要)
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# 安装 Yarn
npm install -g yarn
```

### 3. 安装 Ruby (使用 rbenv)
```bash
# 安装 rbenv
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# 安装 ruby-build
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# 安装 Ruby 3.2.3
rbenv install 3.2.3
rbenv global 3.2.3

# 验证
ruby -v  # 应显示 ruby 3.2.3
```

---

## 二、数据库配置

### 1. 配置 PostgreSQL
```bash
# 切换到 postgres 用户
sudo -u postgres psql

# 在 psql 中执行：
CREATE USER craftletkoma WITH PASSWORD 'mabo1992';
CREATE DATABASE craftlet_production OWNER craftletkoma;
GRANT ALL PRIVILEGES ON DATABASE craftlet_production TO craftletkoma;
\q
```

### 2. 配置 Redis
```bash
# 启动 Redis
systemctl enable redis-server
systemctl start redis-server

# 验证
redis-cli ping  # 应返回 PONG
```

---

## 三、部署应用

### 1. 克隆代码
```bash
cd /var/www
git clone <你的仓库地址> craftlet
cd craftlet
```

### 2. 安装依赖
```bash
# 安装 Bundler
gem install bundler

# 安装 Ruby gems
bundle install --without development test

# 安装 Node 依赖（如果有）
yarn install
```

### 3. 配置环境变量
```bash
# 创建 .env 文件
cat > .env << 'EOF'
RAILS_ENV=production
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true

# 数据库
DATABASE_URL=postgresql://craftletkoma:mabo1992@localhost/craftlet_production

# Redis
REDIS_URL=redis://localhost:6379/1

# 密钥（生成新的）
RAILS_MASTER_KEY=<运行 rails secret 生成>
SECRET_KEY_BASE=<运行 rails secret 生成>
EOF

# 生成密钥
bundle exec rails secret  # 复制输出到 RAILS_MASTER_KEY
bundle exec rails secret  # 复制输出到 SECRET_KEY_BASE
```

### 4. 数据库初始化
```bash
# 运行迁移
RAILS_ENV=production bundle exec rails db:create
RAILS_ENV=production bundle exec rails db:migrate

# 加载种子数据
RAILS_ENV=production bundle exec rails db:seed

# 创建管理员账号
RAILS_ENV=production bundle exec rails runner "
  AdminUser.create!(
    email: 'admin@komaprogram.xyz',
    password: 'Admin@123456',
    password_confirmation: 'Admin@123456',
    role: 'super_admin'
  )
"
```

### 5. 预编译资源
```bash
RAILS_ENV=production bundle exec rails assets:precompile
```

---

## 四、配置 Systemd 服务

### 1. Rails 服务
```bash
cat > /etc/systemd/system/craftlet-web.service << 'EOF'
[Unit]
Description=Craftlet Rails Web Server
After=network.target postgresql.service redis.service

[Service]
Type=simple
User=root
WorkingDirectory=/var/www/craftlet
Environment=RAILS_ENV=production
EnvironmentFile=/var/www/craftlet/.env
ExecStart=/root/.rbenv/shims/bundle exec puma -C config/puma.rb
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
```

### 2. Sidekiq 服务
```bash
cat > /etc/systemd/system/craftlet-sidekiq.service << 'EOF'
[Unit]
Description=Craftlet Sidekiq Worker
After=network.target postgresql.service redis.service

[Service]
Type=simple
User=root
WorkingDirectory=/var/www/craftlet
Environment=RAILS_ENV=production
EnvironmentFile=/var/www/craftlet/.env
ExecStart=/root/.rbenv/shims/bundle exec sidekiq
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
```

### 3. 启动服务
```bash
systemctl daemon-reload
systemctl enable craftlet-web craftlet-sidekiq
systemctl start craftlet-web craftlet-sidekiq

# 检查状态
systemctl status craftlet-web
systemctl status craftlet-sidekiq
```

---

## 五、配置 Nginx

```bash
cat > /etc/nginx/sites-available/craftlet << 'EOF'
upstream craftlet {
  server 127.0.0.1:3000 fail_timeout=0;
}

server {

  listen 80;
  server_name komaprogram.xyz www.komaprogram.xyz 154.219.107.73;

  root /var/www/craftlet/public;

  location / {
    proxy_pass http://craftlet;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location ~ ^/(assets|packs)/ {
    gzip_static on;
    expires max;
    add_header Cache-Control public;
  }

  error_page 500 502 503 504 /500.html;
  client_max_body_size 50M;
  keepalive_timeout 10;
}
EOF

# 启用站点
ln -s /etc/nginx/sites-available/craftlet /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
```

---

## 六、验证部署

### 1. 检查服务状态
```bash
systemctl status craftlet-web
systemctl status craftlet-sidekiq
systemctl status nginx
```

### 2. 查看日志
```bash
# Rails 日志
journalctl -u craftlet-web -f

# Sidekiq 日志
journalctl -u craftlet-sidekiq -f

# Nginx 日志
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

### 3. 访问应用
- 后台管理: http://komaprogram.xyz/admin
- 登录账号: admin@komaprogram.xyz
- 密码: Admin@123456

---

## 七、常用运维命令

```bash
# 重启服务
systemctl restart craftlet-web
systemctl restart craftlet-sidekiq

# 查看日志
journalctl -u craftlet-web -n 100
journalctl -u craftlet-sidekiq -n 100

# 进入 Rails console
cd /var/www/craftlet
RAILS_ENV=production bundle exec rails c

# 运行迁移
RAILS_ENV=production bundle exec rails db:migrate

# 更新代码
cd /var/www/craftlet
git pull
bundle install
RAILS_ENV=production bundle exec rails db:migrate
RAILS_ENV=production bundle exec rails assets:precompile
systemctl restart craftlet-web craftlet-sidekiq
```

---

## 八、安全建议

1. **配置防火墙**
```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

2. **配置 SSL (可选)**
```bash
apt install certbot python3-certbot-nginx
certbot --nginx -d komaprogram.xyz -d www.komaprogram.xyz
```

3. **定期备份数据库**
```bash
# 创建备份脚本
cat > /root/backup-db.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
pg_dump -U craftletkoma craftlet_production > /root/backups/db_$DATE.sql
find /root/backups -name "db_*.sql" -mtime +7 -delete
EOF

chmod +x /root/backup-db.sh
mkdir -p /root/backups

# 添加到 crontab (每天凌晨2点备份)
crontab -e
# 添加: 0 2 * * * /root/backup-db.sh
```

---

## 九、使用 Capistrano 自动化部署

### 1. 首次设置

#### 本地准备
```bash
# 安装 Capistrano gems（已在 Gemfile 中配置）
bundle install

# 修改 config/deploy.rb 中的仓库地址
# set :repo_url, "git@github.com:YOUR_USERNAME/craftlet.git"
```

#### 服务器准备
```bash
# 1. 确保服务器可以 SSH 无密码登录
ssh-copy-id root@154.219.107.73

# 2. 在服务器上创建共享目录
ssh root@154.219.107.73
mkdir -p /var/www/craftlet/shared/config
mkdir -p /var/www/craftlet/shared/log
mkdir -p /var/www/craftlet/shared/tmp/pids
mkdir -p /var/www/craftlet/shared/tmp/cache
mkdir -p /var/www/craftlet/shared/tmp/sockets
mkdir -p /var/www/craftlet/shared/vendor/bundle
mkdir -p /var/www/craftlet/shared/public/system
mkdir -p /var/www/craftlet/shared/storage

# 3. 上传 .env 文件到服务器
scp .env.production root@154.219.107.73:/var/www/craftlet/shared/.env

# 4. 上传 master.key
scp config/master.key root@154.219.107.73:/var/www/craftlet/shared/config/master.key

# 5. 确保服务器已添加 GitHub SSH Key
ssh root@154.219.107.73
ssh-keygen -t ed25519 -C "server@komaprogram.xyz"
cat ~/.ssh/id_ed25519.pub
# 将输出的公钥添加到 GitHub 仓库的 Deploy Keys
```

### 2. 部署命令

```bash
# 检查部署配置
bundle exec cap production deploy:check

# 执行完整部署
bundle exec cap production deploy

# 部署指定分支
BRANCH=feature-xxx bundle exec cap production deploy

# 回滚到上一个版本
bundle exec cap production deploy:rollback
```

### 3. 常用运维命令

```bash
# 查看应用状态
bundle exec cap production app:status

# 查看 Rails 日志
bundle exec cap production logs:rails

# 查看 Puma 日志
bundle exec cap production logs:puma

# 查看 Sidekiq 日志
bundle exec cap production logs:sidekiq

# 数据库备份
bundle exec cap production db:backup

# 清理缓存
bundle exec cap production app:clear_cache

# 打开远程 Rails 控制台
bundle exec cap production rails:console

# 运行数据库种子
bundle exec cap production rails:seed

# 重启 Puma
bundle exec cap production puma:restart

# 重启 Sidekiq
bundle exec cap production sidekiq:restart
```

### 4. 部署流程说明

Capistrano 执行 `cap production deploy` 时会自动完成：

1. ✅ 从 GitHub 拉取最新代码
2. ✅ 创建新的 release 目录
3. ✅ 链接共享文件（.env, master.key, log, storage 等）
4. ✅ 安装 Ruby gems（bundle install）
5. ✅ 预编译 Assets（rails assets:precompile）
6. ✅ 运行数据库迁移（rails db:migrate）
7. ✅ 重启 Puma 和 Sidekiq
8. ✅ 清理旧版本（保留最近 5 个）

### 5. 目录结构

部署后服务器目录结构：
```
/var/www/craftlet/
├── current -> /var/www/craftlet/releases/20260129xxxxxx  # 当前版本符号链接
├── releases/                                              # 所有发布版本
│   ├── 20260129010000/
│   ├── 20260129020000/
│   └── ...
├── shared/                                                # 共享文件
│   ├── .env                                               # 环境变量
│   ├── config/
│   │   └── master.key
│   ├── log/
│   │   └── production.log
│   ├── tmp/
│   │   ├── pids/
│   │   ├── cache/
│   │   └── sockets/
│   ├── vendor/
│   │   └── bundle/
│   └── storage/
└── repo/                                                  # Git 仓库缓存
```

### 6. 故障排查

```bash
# 查看最近部署日志
cat log/capistrano.log

# SSH 到服务器检查
ssh root@154.219.107.73

# 检查服务状态
systemctl status craftlet-web
systemctl status craftlet-sidekiq

# 检查进程
ps aux | grep puma
ps aux | grep sidekiq

# 手动重启服务
systemctl restart craftlet-web
systemctl restart craftlet-sidekiq
```

