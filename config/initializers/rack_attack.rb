# frozen_string_literal: true

# Rack::Attack — 请求限流配置
# 防止暴力破解、撞库攻击
class Rack::Attack
  ### =============================
  ### 缓存后端（使用 Rails cache store）
  ### =============================
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new if Rails.env.test? || Rails.env.development?

  ### =============================
  ### 限流规则 (Throttles)
  ### =============================

  # --- API 登录限流 (按 IP) ---
  # 同一 IP，5 分钟内最多 5 次登录尝试
  throttle("logins/ip", limit: 5, period: 5.minutes) do |req|
    if req.path == "/api/v1/users/sign_in" && req.post?
      req.ip
    end
  end

  # --- API 登录限流 (按 Email) ---
  # 同一邮箱，5 分钟内最多 5 次登录尝试
  throttle("logins/email", limit: 5, period: 5.minutes) do |req|
    if req.path == "/api/v1/users/sign_in" && req.post?
      begin
        body = JSON.parse(req.body.read)
        req.body.rewind
        body.dig("user", "email")&.downcase&.strip
      rescue JSON::ParserError
        nil
      end
    end
  end

  # --- Admin 登录限流 (按 IP) ---
  # 同一 IP，5 分钟内最多 5 次管理后台登录尝试
  throttle("admin_logins/ip", limit: 5, period: 5.minutes) do |req|
    if req.path == "/admin/login" && req.post?
      req.ip
    end
  end

  # --- 注册限流 (按 IP) ---
  # 同一 IP，1 小时内最多 3 次注册
  throttle("registrations/ip", limit: 3, period: 1.hour) do |req|
    if req.path =~ %r{/users\z} && req.post?
      req.ip
    end
  end

  # --- 密码重置限流 (按 IP) ---
  # 同一 IP，1 小时内最多 3 次密码重置
  throttle("password_resets/ip", limit: 3, period: 1.hour) do |req|
    if req.path =~ %r{/users/password\z} && req.post?
      req.ip
    end
  end

  # --- 全局限流 (按 IP) ---
  # 同一 IP，每分钟最多 300 次请求（排除静态资源和健康检查）
  throttle("req/ip", limit: 300, period: 1.minute) do |req|
    req.ip unless req.path.start_with?("/assets") || req.path == "/up"
  end

  ### =============================
  ### 被限流后的响应
  ### =============================
  self.throttled_responder = lambda do |req|
    match_data = req.env["rack.attack.match_data"] || {}
    retry_after = match_data[:period]

    headers = {
      "Content-Type" => "application/json; charset=utf-8",
      "Retry-After" => retry_after.to_s
    }

    body = {
      error: "请求过于频繁，请稍后再试",
      retry_after: retry_after
    }.to_json

    [429, headers, [body]]
  end

  ### =============================
  ### 安全日志
  ### =============================
  ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
    req = payload[:request]
    Rails.logger.warn(
      "[Rack::Attack] Throttled #{req.env['rack.attack.match_discriminator']} " \
      "#{req.ip} #{req.request_method} #{req.path}"
    )
  end
end
