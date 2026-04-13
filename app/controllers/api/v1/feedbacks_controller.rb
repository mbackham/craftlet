# frozen_string_literal: true

module Api
  module V1
    # FeedbacksController — 用户反馈 API
    # FeedbacksController — User feedback API
    #
    # Week 1 改造 / Week 1 refactor:
    #   - 跳过 JWT 认证（反馈为公开表单，未登录用户也可提交）
    #   - 硬编码中文字符串改为 I18n.t 调用
    #
    #   - Skip JWT auth (feedback is a public form, anonymous users can submit)
    #   - Hardcoded Chinese strings replaced with I18n.t calls
    #
    # 注意 / Note:
    #   captcha 使用 RuCaptcha（session），ActionController::API 无 session。
    #   本控制器需要 ActionController::Base。如果架构改为 API-only 可改用无状态验证码。
    #
    #   captcha uses RuCaptcha (session). ActionController::API has no session.
    #   This controller needs ActionController::Base (mixed mode). If moving to
    #   fully API-only, switch to a stateless captcha solution.
    class FeedbacksController < BaseController
      # 反馈为公开表单 — 跳过 JWT 认证
      # Feedback is a public form — skip JWT auth
      skip_before_action :authenticate_from_logto!

      # GET /api/v1/feedbacks/captcha
      # ⚠️  KI-W1-01: RuCaptcha 依赖 session；ActionController::API 无 session。
      # 返回占位响应；生产环境建议迁移至无状态验证码（如 Google reCAPTCHA）。
      # ⚠️  KI-W1-01: RuCaptcha requires session; ActionController::API has no session.
      # Returns placeholder response; production should migrate to stateless captcha.
      def captcha
        captcha_image = if RuCaptcha.respond_to?(:generate_captcha)
                          begin
                            RuCaptcha.generate_captcha
                          rescue => e
                            Rails.logger.warn("[FeedbacksController#captcha] #{e.message}")
                            nil
                          end
                        end
        captcha_key = SecureRandom.hex(16)

        render json: {
          captcha_image: captcha_image,
          captcha_key:   captcha_key
        }
      end

      # POST /api/v1/feedbacks
      def create
        # 验证码检查 / Captcha verification
        # verify_rucaptcha? 仅在 ActionController::Base 中可用（需要 session）
        # 在 ActionController::API 模式下降级跳过（Rack::Attack 限流保护）
        # verify_rucaptcha? only available in ActionController::Base (requires session)
        # Gracefully degrade in API-only mode (Rack::Attack rate-limiting guards against abuse)
        captcha_ok = respond_to?(:verify_rucaptcha?, true) ? verify_rucaptcha? : true
        unless captcha_ok
          return render_error(
            message: I18n.t('api.feedbacks.invalid_captcha'),
            code:    'invalid_captcha',
            status:  :unprocessable_entity
          )
        end

        @feedback = Feedback.new(feedback_params)

        # 若已登录则关联用户 / Associate with user if authenticated
        @feedback.user = current_user if current_user?

        # 设置环境信息 / Set request context
        @feedback.ip_address = request.remote_ip
        @feedback.user_agent = request.user_agent

        # 处理截图上传 / Handle screenshot uploads
        if params[:screenshots].present?
          @feedback.screenshots.attach(params[:screenshots])
        end

        if @feedback.save
          render_success(
            data: {
              id:                    @feedback.id,
              tracking_number:       @feedback.tracking_number,
              message:               I18n.t('api.feedbacks.submitted'),
              estimated_response_time: I18n.t('api.feedbacks.estimated_response_time')
            },
            status: :created
          )
        else
          render_validation_error(@feedback)
        end
      end

      # GET /api/v1/feedbacks/:id  (id = tracking_number)
      def show
        @feedback = Feedback.find_by!(tracking_number: params[:id])

        render_success(data: {
          tracking_number: @feedback.tracking_number,
          status:          @feedback.status_i18n,
          submitted_at:    @feedback.created_at,
          last_update:     response_message_for(@feedback)
        })
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
        I18n.t("api.feedbacks.status.#{feedback.status}", default: '')
      end
    end
  end
end
