# frozen_string_literal: true

module Api
  module V1
    class BannersController < BaseController
      skip_before_action :authenticate_user!, only: [:index], raise: false

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
