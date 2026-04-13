# frozen_string_literal: true

require 'jwt'
require 'openssl'

module Auth
  # JwtVerifier — 验证 Logto 签发的 RS256 JWT，返回 TokenClaims
  # JwtVerifier — verifies a Logto-issued RS256 JWT and returns TokenClaims
  #
  # 环境变量 / Environment variables:
  #   LOGTO_ISSUER   — JWT iss 声明期望值（必须）
  #                    e.g. https://your-logto.example.com/oidc
  #   LOGTO_AUDIENCE — JWT aud 声明期望值（必须）
  #                    e.g. https://api.craftlet.com
  #
  # 用法 / Usage:
  #   claims = Auth::JwtVerifier.call(token)        # → Auth::TokenClaims
  #   claims = Auth::JwtVerifier.call(token, jwks: custom_jwks)  # 注入 JWKS（测试用）
  #
  # 失败时抛出 / Raises on failure:
  #   Auth::JwtVerifier::VerificationError
  #
  class JwtVerifier
    # 所有验证失败的统一异常 / Unified exception for all verification failures
    class VerificationError < StandardError; end

    # @param token  [String]      Bearer token（不含 "Bearer " 前缀）
    # @param jwks   [Array<Hash>] 可选，注入 JWKS keys（测试 stub 用）
    # @return [Auth::TokenClaims]
    def self.call(token, jwks: nil)
      new(token, jwks: jwks).call
    end

    def initialize(token, jwks: nil)
      @token    = token
      @jwks     = jwks
    end

    def call
      payload, = decode_token
      TokenClaims.from_payload(payload)
    rescue JWT::ExpiredSignature => e
      raise VerificationError, "Token has expired: #{e.message}"
    rescue JWT::ImmatureSignature => e
      raise VerificationError, "Token not yet valid: #{e.message}"
    rescue JWT::InvalidIssuerError => e
      raise VerificationError, "Invalid issuer: #{e.message}"
    rescue JWT::InvalidAudError => e
      raise VerificationError, "Invalid audience: #{e.message}"
    rescue JWT::DecodeError => e
      raise VerificationError, "Token decode failed: #{e.message}"
    rescue JwksFetcher::FetchError => e
      raise VerificationError, "JWKS fetch failed: #{e.message}"
    end

    private

    def decode_token
      JWT.decode(
        @token,
        nil,          # key resolved via jwks_loader
        true,         # verify signature
        algorithms:   ['RS256'],
        iss:          issuer,
        aud:          audience,
        verify_iss:   true,
        verify_aud:   true,
        verify_expiration: true,
        jwks:         { keys: resolved_jwks }
      )
    end

    # 期望的 iss / Expected issuer
    def issuer
      ENV.fetch('LOGTO_ISSUER') do
        raise VerificationError, 'LOGTO_ISSUER environment variable is not set'
      end
    end

    # 期望的 aud / Expected audience
    def audience
      ENV.fetch('LOGTO_AUDIENCE') do
        raise VerificationError, 'LOGTO_AUDIENCE environment variable is not set'
      end
    end

    # 解析 JWKS keys（支持注入 stub）
    # Resolve JWKS keys (supports stub injection for tests)
    def resolved_jwks
      if @jwks
        # 测试时直接注入 / Direct injection for tests
        @jwks
      else
        # 生产：从 Redis 缓存或 Logto 网络获取
        # Production: fetch from Redis cache or Logto network
        JwksFetcher.call
      end
    end
  end
end
