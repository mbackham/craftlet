# frozen_string_literal: true

require 'swagger_helper'

# Feedbacks API — rswag 文档测试
# Feedbacks API — rswag documentation tests
#
# Week 1 已知问题 / Week 1 Known Issues:
#   KI-W1-01: captcha 端点依赖 RuCaptcha + session，与 ActionController::API 不兼容。
#             POST /feedbacks 中验证码校验在 API-only 模式下自动跳过（Rack::Attack 限流代替）。
#             建议后续迁移到无状态验证码方案（如 Google reCAPTCHA）。
#
#   KI-W1-01: captcha endpoint depends on RuCaptcha + session, incompatible with
#             ActionController::API. Captcha check in POST /feedbacks gracefully skips
#             in API-only mode (Rack::Attack rate-limiting guards instead).
#             Recommend migrating to a stateless captcha solution (e.g., Google reCAPTCHA).
#
RSpec.describe 'Feedbacks API', type: :request do
  path '/api/v1/feedbacks/captcha' do
    get '获取验证码' do
      tags '反馈'
      description <<~DESC
        获取图片验证码。
        ⚠️ KI-W1-01: 当前实现依赖 session（RuCaptcha）。API-only 模式下降级返回占位响应。
        建议迁移至无状态验证码方案。
      DESC
      produces 'application/json'

      response '200', '获取成功（captcha_image 可能为 null）' do
        schema type: :object,
               properties: {
                 captcha_image: { type: :string, nullable: true, description: '验证码图片 (Base64)，API-only 模式下为 null' },
                 captcha_key:   { type: :string, description: '验证码 Key' }
               }

        run_test!
      end
    end
  end

  path '/api/v1/feedbacks' do
    post '提交反馈' do
      tags '反馈'
      description '提交用户反馈。跳过 JWT 认证（公开表单），支持匿名提交。验证码在 API-only 模式下自动通过。'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          feedback: {
            type: :object,
            properties: {
              feedback_type:   { type: :string, enum: %w[bug_report feature_request complaint other] },
              subject:         { type: :string },
              content:         { type: :string },
              submitter_name:  { type: :string },
              submitter_email: { type: :string },
              submitter_phone: { type: :string },
              page_url:        { type: :string }
            },
            required: %w[feedback_type subject content submitter_email submitter_name]
          }
        },
        required: %w[feedback]
      }

      response '201', '提交成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     id:                      { type: :integer },
                     tracking_number:         { type: :string },
                     message:                 { type: :string },
                     estimated_response_time: { type: :string }
                   }
                 }
               }

        let(:body) do
          {
            feedback: {
              feedback_type:   'bug_report',
              subject:         'Test subject',
              content:         'Test content for the bug report',
              submitter_name:  'Test User',
              submitter_email: 'test@example.com'
            }
          }
        end

        before do
          # 跳过邮件发送 / Skip mailer delivery
          allow(FeedbackMailer).to receive_message_chain(:submission_confirmation, :deliver_later)
        end

        run_test!
      end

      response '400', '参数不足' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 error: {
                   type: :object,
                   properties: {
                     code:    { type: :string },
                     message: { type: :string }
                   }
                 }
               }

        # 提交空参数，触发 ActionController::ParameterMissing → 400
        let(:body) { {} }
        run_test!
      end
    end
  end

  path '/api/v1/feedbacks/{tracking_number}' do
    get '查看反馈状态' do
      tags '反馈'
      description '通过跟踪编号查询反馈处理状态'
      produces 'application/json'

      parameter name: :tracking_number, in: :path, type: :string

      response '200', '查询成功' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data: {
                   type: :object,
                   properties: {
                     tracking_number: { type: :string },
                     status:          { type: :string },
                     submitted_at:    { type: :string, format: 'date-time' },
                     last_update:     { type: :string }
                   }
                 }
               }

        let!(:feedback) do
          allow(FeedbackMailer).to receive_message_chain(:submission_confirmation, :deliver_later)
          Feedback.create!(
            feedback_type:   'other',
            subject:         'Test',
            content:         'Test content body',
            tracking_number: "FB-TEST-#{SecureRandom.hex(4).upcase}",
            status:          'pending',
            submitter_email: 'show-test@example.com',
            submitter_name:  'Show Tester',
            ip_address:      '127.0.0.1'
          )
        end
        let(:tracking_number) { feedback.tracking_number }

        run_test!
      end

      response '404', '反馈不存在' do
        let(:tracking_number) { 'INVALID-999' }
        run_test!
      end
    end
  end
end
