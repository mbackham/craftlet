# frozen_string_literal: true

# app/controllers/api/v1/uploads_controller.rb
#
# POST /api/v1/upload/presign → 生成 S3 预签名上传 URL
#
module Api
  module V1
    class UploadsController < BaseController
      ALLOWED_CONTENT_TYPES = %w[
        image/jpeg image/png image/webp image/heic image/heif
      ].freeze

      # 单次上传限制 10 MB
      MAX_SIZE = 10 * 1024 * 1024

      # POST /api/v1/upload/presign
      def presign
        content_type = params[:content_type].to_s
        unless ALLOWED_CONTENT_TYPES.include?(content_type)
          return render_error(
            message: I18n.t('api.errors.upload.unsupported_content_type'),
            code: 'unsupported_content_type',
            status: :unprocessable_entity
          )
        end

        file_size = params[:file_size].to_i
        if file_size <= 0 || file_size > MAX_SIZE
          return render_error(
            message: I18n.t('api.errors.upload.invalid_file_size'),
            code: 'invalid_file_size',
            status: :unprocessable_entity
          )
        end

        # 按用途分目录，防止用户互相覆盖
        purpose = sanitize_purpose(params[:purpose])
        ext     = content_type_to_ext(content_type)
        key     = "uploads/#{purpose}/#{current_user.id}/#{SecureRandom.uuid}#{ext}"

        s3       = Aws::S3::Resource.new(region: ENV.fetch('AWS_REGION', 'us-east-1'))
        bucket   = s3.bucket(ENV.fetch('AWS_BUCKET'))
        obj      = bucket.object(key)
        presigned_url = obj.presigned_url(
          :put,
          expires_in:  900,        # 15 分钟内有效
          content_type: content_type,
          content_length: file_size
        )

        render_success(
          data: {
            presigned_url: presigned_url,
            object_key:    key,
            expires_in:    900
          }
        )
      end

      private

      ALLOWED_PURPOSES = %w[avatar merchant_license merchant_idcard order_attachment].freeze

      def sanitize_purpose(raw)
        ALLOWED_PURPOSES.include?(raw.to_s) ? raw.to_s : 'general'
      end

      def content_type_to_ext(ct)
        {
          'image/jpeg' => '.jpg',
          'image/png'  => '.png',
          'image/webp' => '.webp',
          'image/heic' => '.heic',
          'image/heif' => '.heif'
        }.fetch(ct, '')
      end
    end
  end
end
