# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
# 终端 1：启动 Rails
rails server -b 0.0.0.0

# 终端 2：启动 Sidekiq
bundle exec sidekiq

# 访问
# 后台：http://localhost:3000/admin
# API：http://localhost:3000/api/v1/...
# api文档api-docs/index.html

第 1 步：检查部署配置（确认服务器连通和目录结构）
bundle exec cap production deploy:check
第 2 步：执行部署
bundle exec cap production deploy
