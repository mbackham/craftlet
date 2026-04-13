source "https://rubygems.org"

ruby "3.2.3"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.1.3"

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# === Authentication ===
gem "devise"
# ⚠️  devise-jwt 已移除（Week 1 改造，2026-04-13）
# 认证改由 Logto JWT 中间件处理，见 app/services/auth/jwt_verifier.rb
# ⚠️  devise-jwt removed (Week 1 refactor, 2026-04-13)
# Authentication is now handled by the Logto JWT middleware (app/services/auth/jwt_verifier.rb)
# gem "devise-jwt"
#
# jwt gem（原为 devise-jwt 的传递依赖，现直接依赖）
# jwt gem (previously a transitive dep of devise-jwt, now a direct dependency)
gem "jwt", "~> 3.1"

# === Admin ===
gem "activeadmin"
gem "sassc-rails"
gem "rucaptcha"

# === Authorization ===
gem "pundit"

# === Rate Limiting ===
gem "rack-attack"

# === State machine ===
gem "aasm"

# === Background jobs ===
gem "sidekiq"

# === Auditing ===
gem "paper_trail"

# === API ===
gem "rack-cors"

# === API Serializers ===
# Blueprinter — 轻量级、声明式 JSON 序列化
# Blueprinter — lightweight, declarative JSON serialization
gem "blueprinter"

# === API Documentation ===
gem "rswag-api"
gem "rswag-ui"

# === Pagination ===
gem "pagy"

# === Encryption ===
gem "lockbox"
gem "blind_index"

# === File uploads ===
gem "aws-sdk-s3"

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# === Error tracking ===
gem "sentry-ruby"
gem "sentry-rails"

# Use Redis adapter to run Action Cable in production
gem "redis", "~> 4.8"
gem "connection_pool", "~> 2.4"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

gem "dotenv-rails"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]

  # === Testing & API Docs ===
  gem "rspec-rails"
  gem "rswag-specs"
  gem "factory_bot_rails"
  gem "shoulda-matchers"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
  gem "annotate"
  gem "bullet"
  gem "better_errors"
  gem "binding_of_caller"
  gem "pry-rails"

  # === Deployment ===
  gem "capistrano", "~> 3.18", require: false
  gem "capistrano-rails", "~> 1.6", require: false
  gem "capistrano-rbenv", "~> 2.2", require: false
  gem "capistrano-bundler", "~> 2.1", require: false
  gem "capistrano3-puma", "~> 6.0", require: false
  gem "capistrano-sidekiq", "~> 2.3", require: false
  gem "ed25519", "~> 1.3", require: false           # 新增
  gem "bcrypt_pbkdf", "~> 1.1", require: false      # 新增
  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end
