# frozen_string_literal: true

# config/initializers/logto_auth.rb
#
# Logto 认证配置验证 / Logto authentication configuration validation
#
# 在应用启动时验证必要的环境变量是否已设置，避免运行时因缺少配置而出现
# 难以排查的错误。
#
# Validates required environment variables at boot time, preventing
# hard-to-debug runtime errors from missing configuration.
#
# 必须 / Required:
#   LOGTO_JWKS_URI   — Logto JWKS 公钥端点 URL
#                      e.g. https://your-logto.example.com/oidc/jwks
#   LOGTO_ISSUER     — Logto JWT iss 声明期望值
#                      e.g. https://your-logto.example.com/oidc
#   LOGTO_AUDIENCE   — API resource indicator（JWT aud）
#                      e.g. https://api.craftlet.com
#
# 可选 / Optional:
#   LOGTO_WEBHOOK_SECRET — Webhook HMAC-SHA256 签名密钥（若使用 Webhook 则必须）
#                          Webhook HMAC-SHA256 signing secret (required if using webhooks)
#   REDIS_URL            — Redis 连接 URL，默认 redis://localhost:6379/0
#                          Redis connection URL, defaults to redis://localhost:6379/0

Rails.application.config.after_initialize do
  # 跳过 CI 无头环境 / Skip in CI headless environments
  next if Rails.env.test?

  required_vars = %w[LOGTO_JWKS_URI LOGTO_ISSUER LOGTO_AUDIENCE]
  missing = required_vars.reject { |var| ENV[var].present? }

  if missing.any?
    message = "[logto_auth] Missing required environment variables: #{missing.join(', ')}. " \
              "Logto JWT authentication will not function correctly."
    Rails.logger.warn(message)

    # ⚠️  不阻塞启动 — Logto 服务可能尚未部署。
    # JWT 认证中间件在运行时检查此标志，对请求返回 503。
    #
    # ⚠️  Do NOT block boot — Logto may not be deployed yet.
    # The JWT auth middleware checks this flag at runtime and returns 503.
    Rails.application.config.logto_configured = false
  else
    Rails.application.config.logto_configured = true
  end
end
