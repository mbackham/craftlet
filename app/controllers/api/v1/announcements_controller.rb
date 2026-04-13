# frozen_string_literal: true

module Api
  module V1
    class AnnouncementsController < BaseController
      # 公开端点 — 跳过 JWT 认证 / Public endpoint — skip JWT auth
      skip_before_action :authenticate_from_logto!

      def index
        announcements = Announcement.current.ordered

        locale = params[:locale] || I18n.locale.to_s

        render json: announcements.map { |a|
          {
            id: a.id,
            title: a.title[locale] || a.title[I18n.default_locale.to_s] || a.title.values.first,
            content: a.content[locale] || a.content[I18n.default_locale.to_s] || a.content.values.first,
            announcement_type: a.announcement_type,
            is_pinned: a.is_pinned,
            created_at: a.created_at
          }
        }
      end
    end
  end
end
