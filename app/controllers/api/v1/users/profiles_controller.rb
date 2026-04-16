# frozen_string_literal: true

# app/controllers/api/v1/users/profiles_controller.rb
#
# GET  /api/v1/users/profile  → 获取当前用户资料
# PATCH/PUT /api/v1/users/profile → 更新当前用户资料
#
module Api
  module V1
    module Users
      class ProfilesController < BaseController
        # GET /api/v1/users/profile
        def show
          render_success(data: UserBlueprint.render_as_hash(current_user, view: :me))
        end

        # PATCH /api/v1/users/profile
        def update
          if current_user.update(profile_params)
            render_success(data: UserBlueprint.render_as_hash(current_user, view: :me))
          else
            render_validation_error(current_user)
          end
        end

        private

        def profile_params
          params.require(:user).permit(:locale, :country_code, :phone, :nickname, :avatar_key)
        end
      end
    end
  end
end
