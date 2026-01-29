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
