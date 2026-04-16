module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    # 从 WebSocket 连接参数或请求头中提取并验证 Logto JWT Token
    # 前端连接方式：
    #   const socket = new WebSocket(`wss://api.craftlet.com/cable?token=${accessToken}`)
    def find_verified_user
      token = extract_token
      # ⚠️ Fix: 必须 return，否则 token 为空时代码继续执行
      return reject_unauthorized_connection if token.blank?

      claims = Auth::JwtVerifier.call(token)
      user   = Auth::UserSyncService.call(claims)
      user || reject_unauthorized_connection
    rescue Auth::JwtVerifier::VerificationError
      reject_unauthorized_connection
    rescue Auth::JwksFetcher::FetchError => e
      # ⚠️ Fix: JWKS 网络错误也应该拒绝连接，而不是返回 500
      Rails.logger.error("[ActionCable] JWKS fetch failed: #{e.message}")
      reject_unauthorized_connection
    end

    def extract_token
      # 优先从 URL query string 取（WebSocket 标准方式）
      request.params[:token].presence ||
        # 退化到 HTTP Upgrade 请求头
        request.headers['Authorization']&.delete_prefix('Bearer ')&.strip
    end
  end
end
