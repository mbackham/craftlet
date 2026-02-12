# frozen_string_literal: true

module Api
  module V1
    module Feedbacks
      class FeedbacksController < Api::V1::BaseController
        skip_before_action :authenticate_user!, only: [:create, :captcha]
        
        # GET /api/v1/feedbacks/captcha
        def captcha
          render json: {
            captcha_image: RuCaptcha.generate_captcha,
            captcha_key: session.id
          }
        end
        
        # POST /api/v1/feedbacks
        def create
          # 验证码检查
          unless verify_rucaptcha?
            return render json: { error: '验证码错误' }, status: :unprocessable_entity
          end
          
          @feedback = Feedback.new(feedback_params)
          
          # 设置提交者信息
          if current_user
            @feedback.user = current_user
          end
          
          # 设置环境信息
          @feedback.ip_address = request.remote_ip
          @feedback.user_agent = request.user_agent
          
          # 处理截图上传
          if params[:screenshots].present?
            @feedback.screenshots.attach(params[:screenshots])
          end
          
          if @feedback.save
            render json: {
              id: @feedback.id,
              tracking_number: @feedback.tracking_number,
              message: '感谢您的反馈！我们会尽快处理并通过邮件回复您。',
              estimated_response_time: '48小时内'
            }, status: :created
          else
            render json: { 
              error: '提交失败',
              details: @feedback.errors.full_messages 
            }, status: :unprocessable_entity
          end
        end
        
        # GET /api/v1/feedbacks/:tracking_number
        def show
          @feedback = Feedback.find_by!(tracking_number: params[:tracking_number])
          
          render json: {
            tracking_number: @feedback.tracking_number,
            status: @feedback.status_i18n,
            submitted_at: @feedback.created_at,
            last_update: response_message_for(@feedback)
          }
        end
        
        private
        
        def feedback_params
          params.require(:feedback).permit(
            :feedback_type,
            :subject,
            :content,
            :submitter_name,
            :submitter_email,
            :submitter_phone,
            :page_url
          )
        end
        
        def response_message_for(feedback)
          case feedback.status
          when 'pending'
            '我们已收到您的反馈，正在排队处理中...'
          when 'reviewing'
            '客服正在处理您的反馈...'
          when 'resolved'
            feedback.response.presence || '您的反馈已处理完成。'
          when 'closed'
            '该反馈已关闭。'
          end
        end
      end
    end
  end
end
