# frozen_string_literal: true

require 'swagger_helper'

# spec/requests/api/webhooks/logto_swagger_spec.rb
#
# Logto Webhook 接口 Swagger 文档
# 此接口供 Logto Cloud/自部署服务器调用，不供 App 客户端直接调用
# 安全机制：HMAC-SHA256 签名验证（logto-signature-sha-256 请求头）
#
# POST /api/webhooks/logto
#
RSpec.describe 'Logto Webhook API (服务端对服务端)', type: :request do
  path '/api/webhooks/logto' do
    post 'Logto 用户事件 Webhook' do
      tags 'Webhook（服务端对服务端）'
      description <<~DESC
        接收 Logto 用户事件通知，用于保持本地 User 数据与 Logto 同步。

        **⚠️ 此接口不供 App 客户端调用，仅供 Logto 服务器推送事件使用。**

        ---

        **安全验证：**
        - 必须携带 `logto-signature-sha-256` 请求头（HMAC-SHA256 签名）
        - 签名 key 配置于 `LOGTO_WEBHOOK_SECRET` 环境变量
        - 签名不匹配时返回 `401`

        ---

        **支持的事件类型（`event` 字段）：**

        | 事件 | 说明 | 后端行为 |
        |------|------|---------|
        | `User.Deleted` | 用户在 Logto 被删除 | 清空 `external_id`，将用户状态改为 `deactivated` |
        | `User.Data.Updated` | 用户基本信息变更 | 同步 `email`、`phone`、`nickname` |
        | 其他事件 | 未实现的事件类型 | 记录日志，返回 200（忽略处理）|

        ---

        **Rate Limiting：** 同一 IP 每分钟最多 30 次请求
      DESC
      consumes 'application/json'
      produces 'application/json'

      # ── 签名请求头（必须）
      parameter name: :'logto-signature-sha-256',
                in: :header,
                type: :string,
                required: true,
                description: 'HMAC-SHA256(request_body, LOGTO_WEBHOOK_SECRET)，Logto 自动生成并附带'

      # ── 请求体
      parameter name: :body, in: :body, schema: {
        type: :object,
        description: 'Logto Webhook 事件 payload',
        properties: {
          hookId:    { type: :string,  example: 'hook_abc123',      description: 'Logto 中的 Webhook ID' },
          event:     { type: :string,  example: 'User.Data.Updated', description: '事件类型' },
          createdAt: { type: :string,  format: 'date-time',          description: '事件创建时间（ISO 8601）' },
          data: {
            type: :object,
            description: '与事件相关的数据，结构因事件类型而异',
            properties: {
              id:           { type: :string, example: 'logto_user_id_abc123',   description: 'Logto 用户 ID (sub)' },
              primaryEmail: { type: :string, example: 'new@example.com',        description: '新邮箱（User.Data.Updated 时存在）' },
              primaryPhone: { type: :string, example: '+8613800138000',         description: '新手机（User.Data.Updated 时存在）' },
              name:         { type: :string, example: '张三',                   description: '新昵称（User.Data.Updated 时存在）' }
            }
          }
        },
        required: %w[hookId event data]
      }

      # ── 200 正常处理
      response '200', '事件接收成功' do
        schema type: :object,
               properties: {
                 success:  { type: :boolean, example: true },
                 data: {
                   type: :object,
                   properties: {
                     received: { type: :boolean, example: true }
                   }
                 }
               }

        let(:'logto-signature-sha-256') do
          secret = 'test_webhook_secret'
          body_str = {
            hookId: 'hook_test',
            event: 'User.Data.Updated',
            data: { id: 'logto_test_id' }
          }.to_json
          OpenSSL::HMAC.hexdigest('SHA256', secret, body_str)
        end

        let(:body) do
          { hookId: 'hook_test', event: 'User.Data.Updated', data: { id: 'logto_test_id' } }
        end

        before do
          ENV['LOGTO_WEBHOOK_SECRET'] = 'test_webhook_secret'
        end

        run_test!
      end

      # ── 401 签名缺失
      response '401', '签名头缺失' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 error: {
                   type: :object,
                   properties: {
                     code:    { type: :string, example: 'missing_signature' },
                     message: { type: :string, example: 'Missing signature header' }
                   }
                 }
               }

        let(:'logto-signature-sha-256') { '' }
        let(:body) { { hookId: 'h', event: 'User.Deleted', data: { id: 'x' } } }
        before { ENV['LOGTO_WEBHOOK_SECRET'] = 'test_secret' }
        run_test!
      end

      # ── 401 签名错误
      response '401', '签名验证失败（内容已篡改）' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 error: {
                   type: :object,
                   properties: {
                     code:    { type: :string, example: 'invalid_signature' },
                     message: { type: :string, example: 'Invalid signature' }
                   }
                 }
               }

        let(:'logto-signature-sha-256') { 'wrong_signature_value' }
        let(:body) { { hookId: 'h', event: 'User.Deleted', data: { id: 'x' } } }
        before { ENV['LOGTO_WEBHOOK_SECRET'] = 'test_secret' }
        run_test!
      end
    end
  end
end
