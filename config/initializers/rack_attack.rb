# frozen_string_literal: true

# Rack::Attack — 请求限流配置
# Rack::Attack — Request rate limiting configuration
#
# Week 1 改造说明 / Week 1 changes:
#   - 移除 logins/ip 和 logins/email（/api/v1/users/sign_in 路由已删除）
#   - 移除 registrations/ip（注册已改为 Logto，无本地注册路由）
#   - 新增 webhooks/logto 限流（防止 Webhook 端点被刷）
#   - 新增 API 通用限流（按 Bearer token sub 限制已认证请求）
#
#   - Removed logins/ip and logins/email (/api/v1/users/sign_in route deleted)
#   - Removed registrations/ip (registration moved to Logto, no local route)
#   - Added webhooks/logto throttle (prevent webhook endpoint flooding)
#   - Added API generic throttle (rate-limit authenticated requests by token sub)
#
class Rack::Attack
  ### =============================
  ### 缓存后端 / Cache backend
  ### =============================
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new if Rails.env.test? || Rails.env.development?

  ### =============================
  ### 限流规则 / Throttle rules
  ### =============================

  # --- Admin 登录限流（按 IP）/ Admin login throttle (by IP) ---
  # 同一 IP，5 分钟内最多 5 次管理后台登录尝试
  # Same IP, max 5 admin login attempts in 5 minutes
  throttle('admin_logins/ip', limit: 5, period: 5.minutes) do |req|
    req.ip if req.path == '/admin/login' && req.post?
  end

  # --- 密码重置限流（按 IP）/ Password reset throttle (by IP) ---
  # 同一 IP，1 小时内最多 3 次密码重置（Devise :recoverable）
  # Same IP, max 3 password reset attempts per hour (Devise :recoverable)
  throttle('password_resets/ip', limit: 3, period: 1.hour) do |req|
    req.ip if req.path =~ %r{/users/password\z} && req.post?
  end

  # --- 反馈提交限流（按 IP）/ Feedback submit throttle (by IP) ---
  # 同一 IP，1 小时内最多 3 次反馈提交
  # Same IP, max 3 feedback submissions per hour
  throttle('feedbacks/ip', limit: 3, period: 1.hour) do |req|
    req.ip if req.path == '/api/v1/feedbacks' && req.post?
  end

  # --- 反馈提交限流（按 Email）/ Feedback submit throttle (by Email) ---
  # 同一邮箱，1 天内最多 5 次反馈提交
  # Same email, max 5 feedback submissions per day
  throttle('feedbacks/email', limit: 5, period: 1.day) do |req|
    if req.path == '/api/v1/feedbacks' && req.post?
      begin
        body = JSON.parse(req.body.read)
        req.body.rewind
        body.dig('feedback', 'submitter_email')&.downcase&.strip
      rescue JSON::ParserError
        nil
      end
    end
  end

  # --- Logto Webhook 限流（按 IP）/ Logto Webhook throttle (by IP) ---
  # 同一 IP，1 分钟内最多 30 次 Webhook 调用（防止伪造 Webhook 刷库）
  # Same IP, max 30 webhook calls per minute (prevent spoofed webhook flooding)
  throttle('webhooks/logto/ip', limit: 30, period: 1.minute) do |req|
    req.ip if req.path == '/api/webhooks/logto' && req.post?
  end

  # --- 全局限流（按 IP）/ Global throttle (by IP) ---
  # 同一 IP，每分钟最多 300 次请求（排除静态资源和健康检查）
  # Same IP, max 300 requests per minute (excluding assets and health check)
  throttle('req/ip', limit: 300, period: 1.minute) do |req|
    req.ip unless req.path.start_with?('/assets') || req.path == '/up'
  end

  ### =============================
  ### 被限流后的响应 / Throttled response
  ### =============================
  self.throttled_responder = lambda do |req|
    match_data  = req.env['rack.attack.match_data'] || {}
    retry_after = match_data[:period]

    headers = {
      'Content-Type' => 'application/json; charset=utf-8',
      'Retry-After'  => retry_after.to_s
    }

    body = {
      success:     false,
      error: {
        code:        'rate_limited',
        message:     '请求过于频繁，请稍后再试 / Too many requests, please try again later',
        retry_after: retry_after
      }
    }.to_json

    [429, headers, [body]]
  end

  ### =============================
  ### 安全日志 / Security logging
  ### =============================
  ActiveSupport::Notifications.subscribe('throttle.rack_attack') do |_name, _start, _finish, _id, payload|
    req = payload[:request]
    Rails.logger.warn(
      "[Rack::Attack] Throttled #{req.env['rack.attack.match_discriminator']} " \
      "#{req.ip} #{req.request_method} #{req.path}"
    )
  end
end
