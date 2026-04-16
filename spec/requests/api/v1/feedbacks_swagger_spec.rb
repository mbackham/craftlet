# frozen_string_literal: true

require 'swagger_helper'

# spec/requests/api/v1/feedbacks_swagger_spec.rb
#
# 用户反馈模块 Swagger 文档
# 所有接口公开，无需 JWT 认证（Rack::Attack 限流保护）
#
# GET  /api/v1/feedbacks/captcha  — 获取验证码
# POST /api/v1/feedbacks          — 提交反馈
# GET  /api/v1/feedbacks/:id      — 查询反馈进度（id = tracking_number）
#
RSpec.describe 'Feedbacks API (公开)', type: :request do
  # ── 验证码 ────────────────────────────────────────────────────────────────

  path '/api/v1/feedbacks/captcha' do
    get '获取验证码' do
      tags '用户反馈'
      description <<~DESC
        获取验证码图片及 key，用于提交反馈前的人机验证。
        - **无需认证**
        - 返回 `captcha_key` 需在提交反馈时附带（`X-Captcha-Key` 请求头或 body 中）
        - ⚠️ 当前为占位实现（RuCaptcha 依赖 session，API-only 模式下降级），
          生产建议迁移至 Google reCAPTCHA 或 Cloudflare Turnstile
      DESC
      produces 'application/json'

      response '200', '验证码获取成功' do
        schema type: :object,
               properties: {
                 captcha_image: {
                   type: :string,
                   nullable: true,
                   description: 'Base64 编码的验证码图片（SVG/PNG），生产模式下有值，降级模式下为 null'
                 },
                 captcha_key: {
                   type: :string,
                   example: 'a1b2c3d4e5f6...',
                   description: '32 位 hex 随机 key，提交反馈时需携带'
                 }
               },
               required: %w[captcha_key]

        run_test!
      end
    end
  end

  # ── 提交反馈 ──────────────────────────────────────────────────────────────

  path '/api/v1/feedbacks' do
    post '提交用户反馈' do
      tags '用户反馈'
      description <<~DESC
        提交匿名或实名的用户反馈，支持截图上传。
        - **无需认证**（匿名用户也可提交）
        - 若携带有效 JWT，反馈会自动关联当前用户
        - 提交成功后返回 `tracking_number`，可用于后续查询进度
        - Rate Limiting：同一 IP 每小时最多 3 次，同一邮箱每天最多 5 次
      DESC
      consumes 'application/json'
      produces 'application/json'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          feedback: {
            type: :object,
            properties: {
              feedback_type:    { type: :string, enum: %w[bug suggestion complaint other], description: '反馈类型', example: 'bug' },
              subject:          { type: :string, description: '反馈标题（简述）', example: '支付按钮无响应' },
              content:          { type: :string, description: '详细内容', example: '在 iOS 16 上点击支付按钮后没有任何反应…' },
              submitter_name:   { type: :string, description: '提交人姓名（可选）' },
              submitter_email:  { type: :string, format: 'email', description: '提交人邮箱（用于回复通知，可选）', example: 'user@example.com' },
              submitter_phone:  { type: :string, description: '提交人手机（可选）' },
              page_url:         { type: :string, description: '问题发生的页面 URL（可选）', example: '/orders/123' }
            },
            required: %w[feedback_type content]
          }
        },
        required: %w[feedback]
      }

      response '201', '反馈提交成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 data: {
                   type: :object,
                   properties: {
                     id:                      { type: :integer, example: 42 },
                     tracking_number:         { type: :string,  example: 'TRK-20260416-ABCD', description: '追踪号，可用于查询进度' },
                     message:                 { type: :string,  example: '您的反馈已提交，我们将尽快处理' },
                     estimated_response_time: { type: :string,  example: '预计 1-3 个工作日内回复' }
                   },
                   required: %w[tracking_number message]
                 }
               }

        let(:body) { { feedback: { feedback_type: 'bug', content: 'Swagger test feedback' } } }
        run_test!
      end

      response '422', '参数验证失败或验证码错误' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 error: {
                   type: :object,
                   properties: {
                     code:    { type: :string, enum: %w[validation_failed invalid_captcha] },
                     message: { type: :string }
                   }
                 }
               }

        let(:body) { { feedback: { feedback_type: 'invalid_type', content: '' } } }
        run_test!
      end

      response '429', '请求过于频繁（Rate Limited）' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 error: {
                   type: :object,
                   properties: {
                     code:        { type: :string, example: 'rate_limited' },
                     message:     { type: :string, example: '请求过于频繁，请稍后再试' },
                     retry_after: { type: :integer, example: 3600, description: '等待秒数' }
                   }
                 }
               }

        # Note: Rate limiting is disabled in test environment (Rack::Attack.enabled = false)
        # This documents the production behavior
        let(:body) { { feedback: { feedback_type: 'bug', content: 'test' } } }
        run_test! if false # 文档性描述，不实际执行（测试环境禁用限流）
      end
    end
  end

  # ── 查询反馈进度 ──────────────────────────────────────────────────────────

  path '/api/v1/feedbacks/{id}' do
    get '查询反馈进度' do
      tags '用户反馈'
      description <<~DESC
        通过 `tracking_number` 查询反馈处理进度。
        - **无需认证**
        - `{id}` 参数传入提交时返回的 `tracking_number`，而非数字 ID
        - 返回当前状态（`pending` / `processing` / `resolved` / `closed`）
      DESC
      produces 'application/json'

      parameter name: :id,
                in: :path,
                type: :string,
                required: true,
                description: '反馈追踪号（tracking_number），如 TRK-20260416-ABCD'

      response '200', '查询成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 data: {
                   type: :object,
                   properties: {
                     tracking_number: { type: :string,  example: 'TRK-20260416-ABCD' },
                     status:          { type: :string,  enum: %w[pending processing resolved closed], example: 'processing' },
                     submitted_at:    { type: :string,  format: 'date-time' },
                     last_update:     { type: :string,  example: '您的反馈正在处理中', description: '当前状态描述文字（i18n）' }
                   },
                   required: %w[tracking_number status submitted_at]
                 }
               }

        let(:id) do
          feedback = Feedback.create!(
            feedback_type: 'bug',
            content: 'test content',
            tracking_number: 'TRK-SWAGGER-TEST'
          )
          feedback.tracking_number
        end
        run_test!
      end

      response '404', '追踪号不存在' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 error: {
                   type: :object,
                   properties: {
                     code:    { type: :string, example: 'not_found' },
                     message: { type: :string, example: '反馈记录不存在' }
                   }
                 }
               }

        let(:id) { 'TRK-NOT-EXIST' }
        run_test!
      end
    end
  end
end
