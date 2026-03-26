# frozen_string_literal: true

ActiveAdmin.register Banner do
  menu parent: "content_menu", priority: 1, label: proc { I18n.t("admin.labels.banners") }

  permit_params :title_zh, :title_en, :link_url, :image_key, :position, :placement, :status, :start_at, :end_at

  controller do
    include Auditable
    helper AuditHelper

    after_action :audit_create, only: [:create]
    after_action :audit_update, only: [:update]
    after_action :audit_destroy, only: [:destroy]


  end

  # === Scopes ===
  scope :all, default: true
  scope proc { I18n.t("banner_statuses.draft") }, :draft
  scope proc { I18n.t("banner_statuses.active") }, :active
  scope proc { I18n.t("banner_statuses.inactive") }, :inactive

  # === Filters ===
  filter :status, as: :select, collection: Banner::STATUSES.map { |s|
    [I18n.t("banner_statuses.#{s}", default: s.humanize), s]
  }
  filter :placement, as: :select, collection: Banner::PLACEMENTS.map { |p|
    [I18n.t("banner_placements.#{p}", default: p.humanize), p]
  }
  filter :start_at
  filter :end_at
  filter :created_at

  # === Index ===
  index do
    selectable_column
    id_column
    column I18n.t("admin.columns.title") do |banner|
      banner.localized_title
    end
    column I18n.t("admin.columns.placement") do |banner|
      I18n.t("banner_placements.#{banner.placement}", default: banner.placement)
    end
    column I18n.t("admin.columns.position"), :position
    column I18n.t("admin.columns.status") do |banner|
      status_color = case banner.status
                     when "active" then "yes"
                     when "inactive" then "no"
                     else nil
                     end
      status_tag I18n.t("banner_statuses.#{banner.status}", default: banner.status.humanize),
                 class: status_color
    end
    column I18n.t("admin.columns.start_at"), :start_at
    column I18n.t("admin.columns.end_at"), :end_at
    column I18n.t("admin.columns.created_time"), :created_at
    actions name: I18n.t("admin.columns.actions")
  end

  # === Show ===
  show title: proc { |b| b.localized_title } do
    attributes_table do
      row("ID") { |b| b.id }
      Banner::PLACEMENTS.length # force preload

      row(I18n.t("admin.columns.title_zh")) { |b| b.title["zh-CN"] }
      row(I18n.t("admin.columns.title_en")) { |b| b.title["en"] }
      row(I18n.t("admin.columns.link_url")) { |b| b.link_url.present? ? link_to(b.link_url, b.link_url, target: "_blank") : nil }
      row(I18n.t("admin.columns.image_key")) { |b| b.image_key }
      row(I18n.t("admin.columns.placement")) { |b| I18n.t("banner_placements.#{b.placement}", default: b.placement) }
      row(I18n.t("admin.columns.position")) { |b| b.position }
      row(I18n.t("admin.columns.status")) do |b|
        status_color = case b.status
                       when "active" then "yes"
                       when "inactive" then "no"
                       else nil
                       end
        status_tag I18n.t("banner_statuses.#{b.status}", default: b.status.humanize), class: status_color
      end
      row(I18n.t("admin.columns.start_at")) { |b| b.start_at ? l(b.start_at, format: :long) : nil }
      row(I18n.t("admin.columns.end_at")) { |b| b.end_at ? l(b.end_at, format: :long) : nil }
      row(:created_at) { |b| l(b.created_at, format: :long) }
      row(:updated_at) { |b| l(b.updated_at, format: :long) }
    end
  end

  # === Form ===
  form do |f|
    f.inputs I18n.t("admin.panels.multilingual_title") do
      f.input :title_zh, as: :string, label: I18n.t("admin.columns.title_zh")
      f.input :title_en, as: :string, label: I18n.t("admin.columns.title_en")
    end

    f.inputs I18n.t("admin.panels.basic_info") do
      f.input :link_url, hint: I18n.t("admin.forms.link_url_hint")
      f.input :image_key, hint: I18n.t("admin.forms.oss_key_hint")
      f.input :placement, as: :select, collection: Banner::PLACEMENTS.map { |p|
        [I18n.t("banner_placements.#{p}", default: p.humanize), p]
      }
      f.input :position
    end

    f.inputs I18n.t("admin.panels.schedule") do
      f.input :start_at, as: :datepicker, hint: I18n.t("admin.forms.schedule_start_hint")
      f.input :end_at, as: :datepicker, hint: I18n.t("admin.forms.schedule_end_hint")
    end

    f.actions
  end

  # === Member Actions ===
  member_action :activate, method: :put do
    banner = Banner.find(params[:id])
    authorize! :activate, banner

    unless banner.can_activate?
      redirect_to admin_banner_path(banner), alert: I18n.t("admin.alerts.cannot_activate")
      return
    end

    ActiveRecord::Base.transaction do
      old_status = banner.status
      banner.activate!

      AuditService.log!(
        action: "activate",
        actor: current_admin_user,
        target: banner,
        before: { status: old_status },
        after: { status: "active" },
        metadata: { action_type: "banner_activate" },
        request: request
      )
    end

    redirect_to admin_banner_path(banner), notice: I18n.t("admin.notices.banner_activated")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_banner_path(banner), alert: I18n.t("admin.notices.operation_failed", error: e.message)
  end

  member_action :deactivate, method: :put do
    banner = Banner.find(params[:id])
    authorize! :deactivate, banner

    unless banner.can_deactivate?
      redirect_to admin_banner_path(banner), alert: I18n.t("admin.alerts.cannot_deactivate")
      return
    end

    ActiveRecord::Base.transaction do
      old_status = banner.status
      banner.deactivate!

      AuditService.log!(
        action: "deactivate",
        actor: current_admin_user,
        target: banner,
        before: { status: old_status },
        after: { status: "inactive" },
        metadata: { action_type: "banner_deactivate" },
        request: request
      )
    end

    redirect_to admin_banner_path(banner), notice: I18n.t("admin.notices.banner_deactivated")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_banner_path(banner), alert: I18n.t("admin.notices.operation_failed", error: e.message)
  end

  # === Action Items ===
  action_item :activate, only: :show, if: proc { banner.can_activate? && current_admin_user.admin_can?("content:manage") } do
    link_to I18n.t("admin.actions.activate_banner"), activate_admin_banner_path(banner),
            method: :put,
            data: { confirm: I18n.t("admin.confirmations.activate_banner") },
            class: "action-item-button"
  end

  action_item :deactivate, only: :show, if: proc { banner.can_deactivate? && current_admin_user.admin_can?("content:manage") } do
    link_to I18n.t("admin.actions.deactivate_banner"), deactivate_admin_banner_path(banner),
            method: :put,
            data: { confirm: I18n.t("admin.confirmations.deactivate_banner") },
            class: "action-item-button"
  end

  # === Batch Actions ===
  batch_action :activate, if: proc { current_admin_user.admin_can?("content:manage") } do |ids|
    batch_action_collection.find(ids).each do |banner|
      next unless banner.can_activate?

      banner.activate!
    end
    redirect_to collection_path, notice: "#{I18n.t('admin.messages.batch_activated')} #{ids.size}"
  end

  batch_action :deactivate, if: proc { current_admin_user.admin_can?("content:manage") } do |ids|
    batch_action_collection.find(ids).each do |banner|
      next unless banner.can_deactivate?

      banner.deactivate!
    end
    redirect_to collection_path, notice: "#{I18n.t('admin.messages.batch_deactivated')} #{ids.size}"
  end

  # === CSV Export ===
  csv do
    column :id
    column(:title) { |b| b.localized_title }
    column :link_url
    column :image_key
    column :placement
    column :position
    column :status
    column :start_at
    column :end_at
    column :created_at
  end
end
