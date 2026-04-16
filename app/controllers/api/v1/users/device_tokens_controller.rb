# frozen_string_literal: true

# app/controllers/api/v1/users/device_tokens_controller.rb
#
# POST   /api/v1/users/device_tokens     → 注册设备推送 token
# DELETE /api/v1/users/device_tokens/:id → 注销设备推送 token
#
module Api
  module V1
    module Users
      class DeviceTokensController < BaseController
        # POST /api/v1/users/device_tokens
        def create
          token = current_user.device_tokens.find_or_initialize_by(token: device_token_params[:token])
          token.platform = device_token_params[:platform]

          if token.save
            render_success(data: { id: token.id, token: token.token, platform: token.platform }, status: :created)
          else
            render_validation_error(token)
          end
        end

        # DELETE /api/v1/users/device_tokens/:id
        def destroy
          token = current_user.device_tokens.find(params[:id])
          token.destroy!
          head :no_content
        end

        private

        def device_token_params
          params.require(:device_token).permit(:token, :platform)
        end
      end
    end
  end
end
