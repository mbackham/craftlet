# frozen_string_literal: true

module Api
  module V1
    class BannersController < BaseController
      # 公开端点 — 跳过 JWT 认证 / Public endpoint — skip JWT auth
      skip_before_action :authenticate_from_logto!

      def index
        banners = Banner.current.ordered
        banners = banners.where(placement: params[:placement]) if params[:placement].present?

        locale = params[:locale] || I18n.locale.to_s

        render json: banners.map { |b|
          {
            id: b.id,
            title: b.title[locale] || b.title[I18n.default_locale.to_s] || b.title.values.first,
            image_key: b.image_key,
            link_url: b.link_url,
            position: b.position,
            placement: b.placement
          }
        }
      end
    end
  end
end
