# frozen_string_literal: true

require 'rails_helper'
require 'openssl'

# Auth::JwtVerifier 单元测试
# Unit tests for Auth::JwtVerifier
#
# 策略 / Strategy:
#   不依赖真实 Logto 实例。用 OpenSSL 生成临时 RSA 密钥对，
#   直接用 jwt gem 签发测试 token，通过 jwks: stub 注入公钥绕过网络。
#
#   No real Logto instance required. Generates an ephemeral RSA key pair,
#   signs test tokens with the jwt gem directly, and injects the public key
#   via `jwks:` stub to bypass network calls.
#
RSpec.describe Auth::JwtVerifier do
  # 测试用 RSA 密钥对（仅此 describe 块内有效）
  # Ephemeral RSA key pair (scoped to this describe block)
  let(:rsa_key)     { OpenSSL::PKey::RSA.generate(2048) }
  let(:rsa_public)  { rsa_key.public_key }

  # JWK 格式的公钥（注入 verifier 的 jwks: stub）
  # Public key in JWK format (injected via jwks: stub)
  let(:jwk) do
    {
      'kty' => 'RSA',
      'kid' => 'test-kid-001',
      'use' => 'sig',
      'alg' => 'RS256',
      'n'   => Base64.urlsafe_encode64(rsa_public.n.to_s(2), padding: false),
      'e'   => Base64.urlsafe_encode64(rsa_public.e.to_s(2), padding: false)
    }
  end

  let(:jwks_stub) { [jwk] }

  # Logto 期望的 iss / aud
  let(:issuer)   { 'https://logto.test/oidc' }
  let(:audience) { 'https://api.craftlet.test' }
  let(:sub)      { 'logto-user-abc123' }

  # 签发测试 token 的辅助方法（所有参数均为 keyword 参数，避免 Ruby 3 隐式转换歧义）
  # Token signing helper (all keyword args to avoid Ruby 3 implicit conversion ambiguity)
  #
  # 用法 / Usage:
  #   sign_token                                        # 合法 token
  #   sign_token(payload: { exp: Time.now.to_i - 60 }) # 覆盖 exp
  #   sign_token(sign_key: other_rsa_key)               # 用其他密钥签名
  #   sign_token(alg: 'HS256', sign_key: 'secret')      # 用 HS256（攻击模拟）
  def sign_token(payload: {}, sign_key: rsa_key, alg: 'RS256', kid: 'test-kid-001')
    now = Time.now.to_i
    base = {
      'sub'   => sub,
      'iss'   => issuer,
      'aud'   => audience,
      'iat'   => now,
      'exp'   => now + 3600,
      'email' => 'alice@example.com',
      'name'  => 'Alice'
    }.merge(payload.transform_keys(&:to_s))
    JWT.encode(base, sign_key, alg, { kid: kid })
  end

  before do
    stub_const('ENV', ENV.to_hash.merge(
      'LOGTO_ISSUER'   => issuer,
      'LOGTO_AUDIENCE' => audience,
      'LOGTO_JWKS_URI' => 'https://logto.test/oidc/jwks'
    ))
  end

  # -----------------------------------------------------------------------
  # 正常路径 / Happy path
  # -----------------------------------------------------------------------
  describe '.call' do
    context 'with a valid RS256 token' do
      it 'returns a TokenClaims struct with the correct sub' do
        token  = sign_token
        claims = described_class.call(token, jwks: jwks_stub)
        expect(claims).to be_a(Auth::TokenClaims)
        expect(claims.sub).to eq(sub)
      end

      it 'populates email from the token payload' do
        token  = sign_token(payload: { email: 'bob@example.com' })
        claims = described_class.call(token, jwks: jwks_stub)
        expect(claims.email).to eq('bob@example.com')
      end

      it 'populates name from the token payload' do
        token  = sign_token(payload: { name: 'Bob' })
        claims = described_class.call(token, jwks: jwks_stub)
        expect(claims.name).to eq('Bob')
      end

      it 'populates phone_number from the token payload' do
        token  = sign_token(payload: { phone_number: '+8613800138000' })
        claims = described_class.call(token, jwks: jwks_stub)
        expect(claims.phone_number).to eq('+8613800138000')
      end

      it 'exposes logto_id as an alias for sub' do
        token  = sign_token
        claims = described_class.call(token, jwks: jwks_stub)
        expect(claims.logto_id).to eq(sub)
      end

      it 'stores the raw payload' do
        token  = sign_token
        claims = described_class.call(token, jwks: jwks_stub)
        expect(claims.raw).to include('sub' => sub, 'iss' => issuer)
      end
    end
  end

  # -----------------------------------------------------------------------
  # 过期 token / Expired token
  # -----------------------------------------------------------------------
  describe '.call with an expired token' do
    it 'raises VerificationError mentioning expiration' do
      token = sign_token(payload: { exp: Time.now.to_i - 60 })
      expect {
        described_class.call(token, jwks: jwks_stub)
      }.to raise_error(Auth::JwtVerifier::VerificationError, /expired/i)
    end
  end

  # -----------------------------------------------------------------------
  # 错误签名 / Invalid signature
  # -----------------------------------------------------------------------
  describe '.call with a token signed by a different key' do
    it 'raises VerificationError' do
      other_key = OpenSSL::PKey::RSA.generate(2048)
      token = sign_token(sign_key: other_key)
      expect {
        described_class.call(token, jwks: jwks_stub)
      }.to raise_error(Auth::JwtVerifier::VerificationError)
    end
  end

  # -----------------------------------------------------------------------
  # 错误 issuer / Wrong issuer
  # -----------------------------------------------------------------------
  describe '.call with a mismatched issuer' do
    it 'raises VerificationError mentioning issuer' do
      token = sign_token(payload: { iss: 'https://evil.example.com/oidc' })
      expect {
        described_class.call(token, jwks: jwks_stub)
      }.to raise_error(Auth::JwtVerifier::VerificationError, /issuer/i)
    end
  end

  # -----------------------------------------------------------------------
  # 错误 audience / Wrong audience
  # -----------------------------------------------------------------------
  describe '.call with a mismatched audience' do
    it 'raises VerificationError mentioning audience' do
      token = sign_token(payload: { aud: 'https://other-api.example.com' })
      expect {
        described_class.call(token, jwks: jwks_stub)
      }.to raise_error(Auth::JwtVerifier::VerificationError, /audience/i)
    end
  end

  # -----------------------------------------------------------------------
  # 畸形 token / Malformed token
  # -----------------------------------------------------------------------
  describe '.call with a malformed token' do
    it 'raises VerificationError for a random string' do
      expect {
        described_class.call('not.a.jwt', jwks: jwks_stub)
      }.to raise_error(Auth::JwtVerifier::VerificationError)
    end

    it 'raises VerificationError for an empty string' do
      expect {
        described_class.call('', jwks: jwks_stub)
      }.to raise_error(Auth::JwtVerifier::VerificationError)
    end
  end

  # -----------------------------------------------------------------------
  # 缺少环境变量 / Missing env vars
  # -----------------------------------------------------------------------
  describe '.call with missing LOGTO_ISSUER' do
    before do
      stub_const('ENV', ENV.to_hash.merge(
        'LOGTO_ISSUER'   => nil,
        'LOGTO_AUDIENCE' => audience,
        'LOGTO_JWKS_URI' => 'https://logto.test/oidc/jwks'
      ).reject { |_k, v| v.nil? })
    end

    it 'raises VerificationError' do
      token = sign_token
      expect {
        described_class.call(token, jwks: jwks_stub)
      }.to raise_error(Auth::JwtVerifier::VerificationError, /LOGTO_ISSUER/)
    end
  end

  describe '.call with missing LOGTO_AUDIENCE' do
    before do
      stub_const('ENV', ENV.to_hash.merge(
        'LOGTO_ISSUER'   => issuer,
        'LOGTO_AUDIENCE' => nil,
        'LOGTO_JWKS_URI' => 'https://logto.test/oidc/jwks'
      ).reject { |_k, v| v.nil? })
    end

    it 'raises VerificationError' do
      token = sign_token
      expect {
        described_class.call(token, jwks: jwks_stub)
      }.to raise_error(Auth::JwtVerifier::VerificationError, /LOGTO_AUDIENCE/)
    end
  end

  # -----------------------------------------------------------------------
  # HS256 算法拒绝（算法混淆攻击）/ HS256 algorithm rejection (algorithm confusion attack)
  # -----------------------------------------------------------------------
  describe '.call with a HS256 token (algorithm confusion attack)' do
    it 'raises VerificationError' do
      token = JWT.encode(
        { 'sub' => sub, 'iss' => issuer, 'aud' => audience, 'exp' => Time.now.to_i + 3600 },
        'secret', 'HS256'
      )
      expect {
        described_class.call(token, jwks: jwks_stub)
      }.to raise_error(Auth::JwtVerifier::VerificationError)
    end
  end
end
