# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Feedbacks API', type: :request do
  path '/api/v1/feedbacks/captcha' do
    get '获取验证码' do
      tags '反馈'
      description '获取图片验证码，用于提交反馈时验证'
      produces 'application/json'

      response '200', '获取成功' do
        schema type: :object,
               properties: {
                 captcha_image: { type: :string, description: '验证码图片 (Base64)' },
                 captcha_key: { type: :string, description: '验证码 Key（提交反馈时需要）' }
               }

        run_test!
      end
    end
  end

  path '/api/v1/feedbacks' do
    post '提交反馈' do
      tags '反馈'
      description '提交用户反馈，需要先获取验证码。支持文字和截图。'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          feedback: {
            type: :object,
            properties: {
              feedback_type: { type: :string, description: '反馈类型' },
              subject: { type: :string, description: '反馈主题' },
              content: { type: :string, description: '反馈内容' },
              submitter_name: { type: :string, description: '提交者姓名' },
              submitter_email: { type: :string, description: '提交者邮箱' },
              submitter_phone: { type: :string, description: '提交者电话' },
              page_url: { type: :string, description: '相关页面 URL' }
            },
            required: %w[feedback_type subject content]
          },
          _rucaptcha: { type: :string, description: '验证码' }
        },
        required: %w[feedback _rucaptcha]
      }

      response '201', '提交成功' do
        schema type: :object,
               properties: {
                 id: { type: :integer, description: '反馈 ID' },
                 tracking_number: { type: :string, description: '跟踪编号' },
                 message: { type: :string, description: '提示信息' },
                 estimated_response_time: { type: :string, description: '预计回复时间' }
               }

        let(:body) { { feedback: { feedback_type: 'bug', subject: 'Test', content: 'Test content' }, _rucaptcha: '1234' } }
        run_test!
      end

      response '422', '提交失败（参数错误或验证码错误）' do
        schema type: :object,
               properties: {
                 error: { type: :string, description: '错误信息' },
                 details: {
                   type: :array,
                   items: { type: :string },
                   description: '详细错误列表'
                 }
               }

        let(:body) { { feedback: { feedback_type: '', subject: '', content: '' }, _rucaptcha: '' } }
        run_test!
      end
    end
  end

  path '/api/v1/feedbacks/{tracking_number}' do
    get '查看反馈状态' do
      tags '反馈'
      description '通过跟踪编号查询反馈处理状态'
      produces 'application/json'

      parameter name: :tracking_number, in: :path, type: :string, description: '反馈跟踪编号'

      response '200', '查询成功' do
        schema type: :object,
               properties: {
                 tracking_number: { type: :string, description: '跟踪编号' },
                 status: { type: :string, description: '处理状态' },
                 submitted_at: { type: :string, format: 'date-time', description: '提交时间' },
                 last_update: { type: :string, description: '最新进展' }
               }

        let(:tracking_number) { 'FB-20260225-000001' }
        run_test!
      end

      response '404', '反馈不存在' do
        let(:tracking_number) { 'INVALID' }
        run_test!
      end
    end
  end
end
