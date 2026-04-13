# frozen_string_literal: true

module Auth
  # TokenClaims — 封装经过验证的 Logto JWT payload
  # TokenClaims — wraps the verified Logto JWT payload
  #
  # 属性 / Attributes:
  #   sub          — Logto 用户 ID（string）/ Logto user ID (string)
  #   email        — 邮箱（可选）/ email (optional)
  #   phone_number — 手机号（可选）/ phone number (optional)
  #   name         — 显示名称（可选）/ display name (optional)
  #   raw          — 原始 payload hash / raw payload hash
  #
  TokenClaims = Struct.new(
    :sub,
    :email,
    :phone_number,
    :name,
    :raw,
    keyword_init: true
  ) do
    # 从原始 JWT payload 构建 TokenClaims
    # Build a TokenClaims from the raw JWT payload hash
    def self.from_payload(payload)
      new(
        sub:          payload['sub'],
        email:        payload['email'],
        phone_number: payload['phone_number'],
        name:         payload['name'],
        raw:          payload
      )
    end

    # Logto user ID（alias for sub）
    def logto_id
      sub
    end
  end
end
