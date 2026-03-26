# frozen_string_literal: true

module Content
  class PublishScheduledContentJob < ApplicationJob
    queue_as :default

    def perform
      publish_banners
      publish_announcements
      expire_announcements
      expire_banners
    end

    private

    # 定时上线 Banner: start_at 到期且为 draft 状态
    def publish_banners
      Banner.draft.where("start_at IS NOT NULL AND start_at <= ?", Time.current).find_each do |banner|
        banner.activate!
        Rails.logger.info "[PublishScheduledContent] Banner ##{banner.id} activated (scheduled)"
      end
    end

    # 定时发布公告: publish_at 到期且为 draft 状态
    def publish_announcements
      Announcement.draft.where("publish_at IS NOT NULL AND publish_at <= ?", Time.current).find_each do |ann|
        ann.publish!
        Rails.logger.info "[PublishScheduledContent] Announcement ##{ann.id} published (scheduled)"
      end
    end

    # 自动过期公告: expire_at 到期且为 published 状态
    def expire_announcements
      Announcement.published.where("expire_at IS NOT NULL AND expire_at <= ?", Time.current).find_each do |ann|
        ann.archive!
        Rails.logger.info "[PublishScheduledContent] Announcement ##{ann.id} archived (expired)"
      end
    end

    # 自动下线 Banner: end_at 到期且为 active 状态
    def expire_banners
      Banner.active.where("end_at IS NOT NULL AND end_at <= ?", Time.current).find_each do |banner|
        banner.deactivate!
        Rails.logger.info "[PublishScheduledContent] Banner ##{banner.id} deactivated (expired)"
      end
    end
  end
end
