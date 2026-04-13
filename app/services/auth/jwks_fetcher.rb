# frozen_string_literal: true

require 'net/http'
require 'json'

module Auth
  # JwksFetcher — 从 Logto JWKS 端点获取公钥集，并在 Redis 中缓存 1 小时
  # JwksFetcher — fetches the JWKS public key set from Logto and caches it in Redis for 1 hour
  #
  # 环境变量 / Environment variables:
  #   LOGTO_JWKS_URI  — Logto JWKS 端点 URL（必须）
  #                     e.g. https://your-logto.example.com/oidc/jwks
  #
  # 用法 / Usage:
  #   jwks = Auth::JwksFetcher.call          # → Array<Hash>  JWKS key objects
  #   jwks = Auth::JwksFetcher.call(force: true)  # 强制跳过缓存 / force bypass cache
  #
  class JwksFetcher
    CACHE_KEY = 'auth:logto:jwks'
    CACHE_TTL = 3600 # seconds — 1 hour

    class FetchError < StandardError; end

    # 主入口 / Main entry point
    # @param force [Boolean] 是否跳过缓存 / whether to bypass cache
    # @return [Array<Hash>]  JWK objects array
    def self.call(force: false)
      new.call(force: force)
    end

    def call(force: false)
      unless force
        cached = redis_get(CACHE_KEY)
        return JSON.parse(cached) if cached
      end

      keys = fetch_from_logto
      redis_set(CACHE_KEY, keys.to_json, ex: CACHE_TTL)
      keys
    end

    private

    def jwks_uri
      uri = ENV.fetch('LOGTO_JWKS_URI') do
        raise FetchError, 'LOGTO_JWKS_URI environment variable is not set'
      end
      URI.parse(uri)
    rescue URI::InvalidURIError => e
      raise FetchError, "Invalid LOGTO_JWKS_URI: #{e.message}"
    end

    def fetch_from_logto
      uri = jwks_uri
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                                      open_timeout: 5,
                                                      read_timeout: 10) do |http|
        http.get(uri.request_uri)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise FetchError, "JWKS endpoint returned #{response.code}: #{response.body&.first(200)}"
      end

      body = JSON.parse(response.body)
      keys = body['keys']
      raise FetchError, 'JWKS response missing "keys" array' unless keys.is_a?(Array)
      raise FetchError, 'JWKS "keys" array is empty' if keys.empty?

      keys
    rescue JSON::ParserError => e
      raise FetchError, "Failed to parse JWKS response: #{e.message}"
    rescue Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
      raise FetchError, "Network error fetching JWKS: #{e.message}"
    end

    # Redis 操作封装（兼容 Redis 4.x 和 5.x）
    # Redis operation wrappers (compatible with Redis 4.x and 5.x)
    def redis
      @redis ||= Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    end

    def redis_get(key)
      redis.get(key)
    rescue Redis::BaseError => e
      Rails.logger.warn("[JwksFetcher] Redis GET failed: #{e.message}; falling back to network")
      nil
    end

    def redis_set(key, value, ex:)
      redis.set(key, value, ex: ex)
    rescue Redis::BaseError => e
      Rails.logger.warn("[JwksFetcher] Redis SET failed: #{e.message}; cache not written")
    end
  end
end
