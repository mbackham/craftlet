# 数据备份与恢复指南

## 自动备份

### 配置

备份脚本位于 `scripts/pg_backup.sh`，支持以下环境变量：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `BACKUP_DIR` | `/var/backups/postgresql` | 备份存储目录 |
| `DB_NAME` | `craftlet_production` | 数据库名 |
| `DB_USER` | `rails` | 数据库用户 |
| `DB_HOST` | `localhost` | 数据库主机 |
| `DB_PORT` | `5432` | 数据库端口 |

### 保留策略

- **每日备份**：保留最近 7 天
- **每周备份**：每周日自动复制一份，保留最近 4 周

### Cron 配置

```bash
# 每天凌晨 2:00 执行备份
echo "0 2 * * * /home/rails/projects/craftlet/scripts/pg_backup.sh >> /var/log/pg_backup.log 2>&1" | sudo crontab -u rails -
```

### 手动执行

```bash
bash scripts/pg_backup.sh
```

---

## 恢复操作

### 从备份恢复（整库）

```bash
# 1. 停止应用
sudo systemctl stop puma

# 2. 删除并重建数据库
dropdb -U rails craftlet_production
createdb -U rails craftlet_production

# 3. 恢复备份
pg_restore \
  --host=localhost \
  --username=rails \
  --dbname=craftlet_production \
  --verbose \
  /var/backups/postgresql/daily/craftlet_YYYYMMDD_HHMMSS.sql.gz

# 4. 重启应用
sudo systemctl start puma
```

### 恢复单个表

```bash
pg_restore \
  --host=localhost \
  --username=rails \
  --dbname=craftlet_production \
  --table=orders \
  --verbose \
  /var/backups/postgresql/daily/craftlet_YYYYMMDD_HHMMSS.sql.gz
```

### 查看备份内容

```bash
pg_restore --list /var/backups/postgresql/daily/craftlet_YYYYMMDD_HHMMSS.sql.gz
```
