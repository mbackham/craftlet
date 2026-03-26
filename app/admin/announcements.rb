# frozen_string_literal: true

ActiveAdmin.register Announcement do
  menu parent: "content_menu", priority: 2, label: proc { I18n.t("admin.labels.announcements") }

  permit_params :title_zh, :title_en, :content_zh, :content_en, :announcement_type, :status, :is_pinned, :publish_at, :expire_at

  controller do
    include Auditable
    helper AuditHelper

    after_action :audit_create, only: [:create]
    after_action :audit_update, only: [:update]
    after_action :audit_destroy, only: [:destroy]


  end

  # === Scopes ===
  scope :all, default: true
  scope proc { I18n.t("announcement_statuses.draft") }, :draft
  scope proc { I18n.t("announcement_statuses.published") }, :published
  scope proc { I18n.t("announcement_statuses.archived") }, :archived
  scope proc { I18n.t("admin.scopes.pinned") }, :pinned

  # === Filters ===
  filter :status, as: :select, collection: Announcement::STATUSES.map { |s|
    [I18n.t("announcement_statuses.#{s}", default: s.humanize), s]
  }
  filter :announcement_type, as: :select, collection: Announcement::TYPES.map { |t|
    [I18n.t("announcement_types.#{t}", default: t.humanize), t]
  }
  filter :is_pinned
  filter :publish_at
  filter :expire_at
  filter :created_at

  # === Index ===
  index do
    selectable_column
    id_column
    column I18n.t("admin.columns.title") do |ann|
      ann.localized_title
    end
    column I18n.t("admin.columns.type") do |ann|
      I18n.t("announcement_types.#{ann.announcement_type}", default: ann.announcement_type)
    end
    column I18n.t("admin.columns.is_pinned") do |ann|
      status_tag(ann.is_pinned ? I18n.t("active_admin.status_tag.yes") : I18n.t("active_admin.status_tag.no"),
                 class: ann.is_pinned ? "yes" : nil)
    end
    column I18n.t("admin.columns.status") do |ann|
      status_color = case ann.status
                     when "published" then "yes"
                     when "archived" then "no"
                     else nil
                     end
      status_tag I18n.t("announcement_statuses.#{ann.status}", default: ann.status.humanize),
                 class: status_color
    end
    column I18n.t("admin.columns.publish_at"), :publish_at
    column I18n.t("admin.columns.expire_at"), :expire_at
    column I18n.t("admin.columns.created_time"), :created_at
    actions name: I18n.t("admin.columns.actions")
  end

  # === Show ===
  show title: proc { |a| a.localized_title } do
    attributes_table do
      row("ID") { |a| a.id }
      row(I18n.t("admin.columns.title_zh")) { |a| a.title["zh-CN"] }
      row(I18n.t("admin.columns.title_en")) { |a| a.title["en"] }
      row(I18n.t("admin.columns.content_zh")) { |a| simple_format(a.content["zh-CN"]) if a.content["zh-CN"].present? }
      row(I18n.t("admin.columns.content_en")) { |a| simple_format(a.content["en"]) if a.content["en"].present? }
      row(I18n.t("admin.columns.type")) { |a| I18n.t("announcement_types.#{a.announcement_type}", default: a.announcement_type) }
      row(I18n.t("admin.columns.is_pinned")) do |a|
        status_tag(a.is_pinned ? I18n.t("active_admin.status_tag.yes") : I18n.t("active_admin.status_tag.no"),
                   class: a.is_pinned ? "yes" : nil)
      end
      row(I18n.t("admin.columns.status")) do |a|
        status_color = case a.status
                       when "published" then "yes"
                       when "archived" then "no"
                       else nil
                       end
        status_tag I18n.t("announcement_statuses.#{a.status}", default: a.status.humanize), class: status_color
      end
      row(I18n.t("admin.columns.publish_at")) { |a| a.publish_at ? l(a.publish_at, format: :long) : nil }
      row(I18n.t("admin.columns.expire_at")) { |a| a.expire_at ? l(a.expire_at, format: :long) : nil }
      row(:created_at) { |a| l(a.created_at, format: :long) }
      row(:updated_at) { |a| l(a.updated_at, format: :long) }
    end
  end

  # === Form ===
  form do |f|
    f.inputs I18n.t("admin.panels.multilingual_title") do
      f.input :title_zh, as: :string, label: I18n.t("admin.columns.title_zh")
      f.input :title_en, as: :string, label: I18n.t("admin.columns.title_en")
    end

    f.inputs I18n.t("admin.panels.multilingual_content") do
      f.input :content_zh, as: :text, label: I18n.t("admin.columns.content_zh"), input_html: { rows: 5 }
      f.input :content_en, as: :text, label: I18n.t("admin.columns.content_en"), input_html: { rows: 5 }
    end

    f.inputs I18n.t("admin.panels.basic_info") do
      f.input :announcement_type, as: :select, collection: Announcement::TYPES.map { |t|
        [I18n.t("announcement_types.#{t}", default: t.humanize), t]
      }
      f.input :is_pinned
    end

    f.inputs I18n.t("admin.panels.schedule") do
      f.input :publish_at, as: :datepicker, hint: I18n.t("admin.forms.publish_at_hint")
      f.input :expire_at, as: :datepicker, hint: I18n.t("admin.forms.expire_at_hint")
    end

    f.actions
  end

  # === Member Actions ===
  member_action :publish_now, method: :put do
    announcement = Announcement.find(params[:id])
    authorize! :publish, announcement

    unless announcement.can_publish?
      redirect_to admin_announcement_path(announcement), alert: I18n.t("admin.alerts.cannot_publish")
      return
    end

    ActiveRecord::Base.transaction do
      old_status = announcement.status
      announcement.publish!

      AuditService.log!(
        action: "publish",
        actor: current_admin_user,
        target: announcement,
        before: { status: old_status },
        after: { status: "published" },
        metadata: { action_type: "announcement_publish" },
        request: request
      )
    end

    redirect_to admin_announcement_path(announcement), notice: I18n.t("admin.notices.announcement_published")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_announcement_path(announcement), alert: I18n.t("admin.notices.operation_failed", error: e.message)
  end

  member_action :archive_now, method: :put do
    announcement = Announcement.find(params[:id])
    authorize! :archive, announcement

    unless announcement.can_archive?
      redirect_to admin_announcement_path(announcement), alert: I18n.t("admin.alerts.cannot_archive")
      return
    end

    ActiveRecord::Base.transaction do
      old_status = announcement.status
      announcement.archive!

      AuditService.log!(
        action: "archive",
        actor: current_admin_user,
        target: announcement,
        before: { status: old_status },
        after: { status: "archived" },
        metadata: { action_type: "announcement_archive" },
        request: request
      )
    end

    redirect_to admin_announcement_path(announcement), notice: I18n.t("admin.notices.announcement_archived")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_announcement_path(announcement), alert: I18n.t("admin.notices.operation_failed", error: e.message)
  end

  # === Action Items ===
  action_item :publish, only: :show, if: proc { announcement.can_publish? && current_admin_user.admin_can?("content:manage") } do
    link_to I18n.t("admin.actions.publish"), publish_now_admin_announcement_path(announcement),
            method: :put,
            data: { confirm: I18n.t("admin.confirmations.publish_announcement") },
            class: "action-item-button"
  end

  action_item :archive, only: :show, if: proc { announcement.can_archive? && current_admin_user.admin_can?("content:manage") } do
    link_to I18n.t("admin.actions.archive"), archive_now_admin_announcement_path(announcement),
            method: :put,
            data: { confirm: I18n.t("admin.confirmations.archive_announcement") },
            class: "action-item-button"
  end

  # === CSV Export ===
  csv do
    column :id
    column(:title) { |a| a.localized_title }
    column :announcement_type
    column :status
    column :is_pinned
    column :publish_at
    column :expire_at
    column :created_at
  end
end
