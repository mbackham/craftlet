# frozen_string_literal: true

ActiveAdmin.register AbTest do
  menu parent: "content_menu", priority: 5, label: proc { I18n.t("admin.labels.ab_tests") }

  permit_params :name, :test_key, :description, :status, :traffic_percentage, :start_at, :end_at, :variants_json

  controller do
    include Auditable
    helper AuditHelper

    after_action :audit_create, only: [:create]
    after_action :audit_update, only: [:update]
    after_action :audit_destroy, only: [:destroy]

  end

  # === Scopes ===
  scope :all, default: true
  scope proc { I18n.t("ab_test_statuses.draft") }, :draft
  scope proc { I18n.t("ab_test_statuses.running") }, :running
  scope proc { I18n.t("ab_test_statuses.paused") }, :paused
  scope proc { I18n.t("ab_test_statuses.completed") }, :completed

  # === Filters ===
  filter :name
  filter :test_key
  filter :status, as: :select, collection: AbTest::STATUSES.map { |s|
    [I18n.t("ab_test_statuses.#{s}", default: s.humanize), s]
  }
  filter :traffic_percentage
  filter :created_at

  # === Index ===
  index do
    selectable_column
    id_column
    column I18n.t("admin.columns.name"), :name
    column I18n.t("admin.columns.test_key"), :test_key
    column I18n.t("admin.columns.status") do |ab|
      status_color = case ab.status
                     when "running" then "yes"
                     when "paused" then "warning"
                     when "completed" then "no"
                     else nil
                     end
      status_tag I18n.t("ab_test_statuses.#{ab.status}", default: ab.status.humanize),
                 class: status_color
    end
    column I18n.t("admin.columns.variants") do |ab|
      ab.variants_summary
    end
    column I18n.t("admin.columns.traffic_percentage") do |ab|
      "#{ab.traffic_percentage}%"
    end
    column I18n.t("admin.columns.start_at"), :start_at
    column I18n.t("admin.columns.end_at"), :end_at
    actions name: I18n.t("admin.columns.actions")
  end

  # === Show ===
  show title: proc { |ab| ab.name } do
    attributes_table do
      row("ID") { |ab| ab.id }
      row(I18n.t("admin.columns.name")) { |ab| ab.name }
      row(I18n.t("admin.columns.test_key")) { |ab| code(ab.test_key) }
      row(I18n.t("admin.columns.description")) { |ab| simple_format(ab.description) if ab.description.present? }
      row(I18n.t("admin.columns.status")) do |ab|
        status_color = case ab.status
                       when "running" then "yes"
                       when "paused" then "warning"
                       when "completed" then "no"
                       else nil
                       end
        status_tag I18n.t("ab_test_statuses.#{ab.status}", default: ab.status.humanize), class: status_color
      end
      row(I18n.t("admin.columns.traffic_percentage")) { |ab| "#{ab.traffic_percentage}%" }
      row(I18n.t("admin.columns.start_at")) { |ab| ab.start_at ? l(ab.start_at, format: :long) : nil }
      row(I18n.t("admin.columns.end_at")) { |ab| ab.end_at ? l(ab.end_at, format: :long) : nil }
      row(:created_at) { |ab| l(ab.created_at, format: :long) }
      row(:updated_at) { |ab| l(ab.updated_at, format: :long) }
    end

    panel I18n.t("admin.panels.variants_config") do
      if ab_test.variants.present?
        table_for ab_test.variants do
          column(I18n.t("admin.columns.variant_name")) { |v| v["name"] }
          column(I18n.t("admin.columns.variant_weight")) { |v| "#{v['weight']}%" }
          column(I18n.t("admin.columns.variant_config")) { |v| code(v["config"].to_json) if v["config"].present? }
        end
      else
        para I18n.t("admin.messages.no_variants")
      end
    end
  end

  # === Form ===
  form do |f|
    f.inputs I18n.t("admin.panels.basic_info") do
      f.input :name
      f.input :test_key, hint: I18n.t("admin.forms.test_key_hint")
      f.input :description, as: :text
      f.input :traffic_percentage, hint: I18n.t("admin.forms.traffic_hint")
    end

    f.inputs I18n.t("admin.panels.variants_config") do
      f.input :variants_json, as: :text, label: I18n.t("admin.columns.variants_json"),
              hint: I18n.t("admin.forms.variants_hint"), input_html: { rows: 10 }
    end

    f.inputs I18n.t("admin.panels.schedule") do
      f.input :start_at, as: :datepicker
      f.input :end_at, as: :datepicker
    end

    f.actions
  end

  # === Member Actions ===
  member_action :start_test, method: :put do
    ab_test = AbTest.find(params[:id])
    authorize! :start, ab_test

    unless ab_test.can_start?
      redirect_to admin_ab_test_path(ab_test), alert: I18n.t("admin.alerts.cannot_start_test")
      return
    end

    ActiveRecord::Base.transaction do
      old_status = ab_test.status
      ab_test.start!

      AuditService.log!(
        action: "start",
        actor: current_admin_user,
        target: ab_test,
        before: { status: old_status },
        after: { status: "running" },
        metadata: { action_type: "ab_test_start" },
        request: request
      )
    end

    redirect_to admin_ab_test_path(ab_test), notice: I18n.t("admin.notices.ab_test_started")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_ab_test_path(ab_test), alert: I18n.t("admin.notices.operation_failed", error: e.message)
  end

  member_action :pause_test, method: :put do
    ab_test = AbTest.find(params[:id])
    authorize! :pause, ab_test

    unless ab_test.can_pause?
      redirect_to admin_ab_test_path(ab_test), alert: I18n.t("admin.alerts.cannot_pause_test")
      return
    end

    ActiveRecord::Base.transaction do
      old_status = ab_test.status
      ab_test.pause!

      AuditService.log!(
        action: "pause",
        actor: current_admin_user,
        target: ab_test,
        before: { status: old_status },
        after: { status: "paused" },
        metadata: { action_type: "ab_test_pause" },
        request: request
      )
    end

    redirect_to admin_ab_test_path(ab_test), notice: I18n.t("admin.notices.ab_test_paused")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_ab_test_path(ab_test), alert: I18n.t("admin.notices.operation_failed", error: e.message)
  end

  member_action :complete_test, method: :put do
    ab_test = AbTest.find(params[:id])
    authorize! :complete, ab_test

    unless ab_test.can_complete?
      redirect_to admin_ab_test_path(ab_test), alert: I18n.t("admin.alerts.cannot_complete_test")
      return
    end

    ActiveRecord::Base.transaction do
      old_status = ab_test.status
      ab_test.complete!

      AuditService.log!(
        action: "complete",
        actor: current_admin_user,
        target: ab_test,
        before: { status: old_status },
        after: { status: "completed" },
        metadata: { action_type: "ab_test_complete" },
        request: request
      )
    end

    redirect_to admin_ab_test_path(ab_test), notice: I18n.t("admin.notices.ab_test_completed")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_ab_test_path(ab_test), alert: I18n.t("admin.notices.operation_failed", error: e.message)
  end

  # === Action Items ===
  action_item :start, only: :show, if: proc { ab_test.can_start? && current_admin_user.admin_can?("content:manage") } do
    link_to I18n.t("admin.actions.start_test"), start_test_admin_ab_test_path(ab_test),
            method: :put,
            data: { confirm: I18n.t("admin.confirmations.start_test") },
            class: "action-item-button"
  end

  action_item :pause, only: :show, if: proc { ab_test.can_pause? && current_admin_user.admin_can?("content:manage") } do
    link_to I18n.t("admin.actions.pause_test"), pause_test_admin_ab_test_path(ab_test),
            method: :put,
            data: { confirm: I18n.t("admin.confirmations.pause_test") },
            class: "action-item-button"
  end

  action_item :complete, only: :show, if: proc { ab_test.can_complete? && current_admin_user.admin_can?("content:manage") } do
    link_to I18n.t("admin.actions.complete_test"), complete_test_admin_ab_test_path(ab_test),
            method: :put,
            data: { confirm: I18n.t("admin.confirmations.complete_test") },
            class: "action-item-button"
  end

  # === CSV Export ===
  csv do
    column :id
    column :name
    column :test_key
    column :status
    column(:variants) { |ab| ab.variants_summary }
    column :traffic_percentage
    column :start_at
    column :end_at
    column :created_at
  end
end
