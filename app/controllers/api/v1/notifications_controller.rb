# frozen_string_literal: true

# app/controllers/api/v1/notifications_controller.rb
#
# GET   /api/v1/notifications          → 通知列表（分页）
# PATCH /api/v1/notifications/mark_read → 批量标记已读
#
module Api
  module V1
    class NotificationsController < BaseController
      include Pagy::Method

      # GET /api/v1/notifications
      def index
        notifications = current_user.notifications.order(created_at: :desc)
        pagy, records = pagy(notifications)
        render_paginated(
          data: NotificationBlueprint.render_as_hash(records),
          pagy: pagy
        )
      end

      # PATCH /api/v1/notifications/mark_read
      # Body: { ids: [1, 2, 3] } 或空（标记全部已读）
      def mark_read
        ids = params[:ids]

        scope = current_user.notifications.unread
        scope = scope.where(id: ids) if ids.present?
        count = scope.update_all(read_at: Time.current)

        render_success(data: { marked_count: count })
      end
    end
  end
end
