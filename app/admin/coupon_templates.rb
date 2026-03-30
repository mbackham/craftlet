# frozen_string_literal: true

ActiveAdmin.register CouponTemplate do
  menu parent: "marketing_menu", priority: 1,
       label: proc { I18n.t("admin.labels.coupon_templates") }

  permit_params :name, :coupon_type, :face_value, :min_order_amount, :status,
                :valid_from, :valid_until, :valid_days, :per_user_limit,
                :total_quota, :budget_amount, :budget_alert_threshold, :description,
                category_ids: [], merchant_ids: [],
                grant_rules: %i[new_user birthday min_level]

  controller do
    include Auditable
    helper AuditHelper

    after_action :audit_create,  only: [:create]
    after_action :audit_update,  only: [:update]
    after_action :audit_destroy, only: [:destroy]
  end

  # === Scopes ===
  scope :all, default: true
  scope proc { I18n.t("coupon_statuses.draft") },    :draft
  scope proc { I18n.t("coupon_statuses.active") },   :active
  scope proc { I18n.t("coupon_statuses.inactive") }, :inactive

  # === Filters ===
  filter :name
  filter :coupon_type, as: :select,
         collection: CouponTemplate::TYPES.map { |t| [I18n.t("coupon_types.#{t}"), t] }
  filter :status, as: :select,
         collection: CouponTemplate::STATUSES.map { |s| [I18n.t("coupon_statuses.#{s}"), s] }
  filter :created_at

  # === Index ===
  index do
    selectable_column
    id_column
    column I18n.t("admin.columns.name"), :name
    column I18n.t("admin.columns.coupon_type") do |t|
      I18n.t("coupon_types.#{t.coupon_type}")
    end
    column I18n.t("admin.columns.face_value") do |t|
      t.discount? ? "#{(t.face_value * 100).to_i}折" : "¥#{t.face_value}"
    end
    column I18n.t("admin.columns.quota") do |t|
      if t.total_quota
        "#{t.issued_count}/#{t.total_quota}"
      else
        "#{t.issued_count}/∞"
      end
    end
    column I18n.t("admin.columns.budget") do |t|
      if t.budget_amount
        "¥#{t.used_amount}/¥#{t.budget_amount}"
      else
        "¥#{t.used_amount}/∞"
      end
    end
    column I18n.t("admin.columns.status") do |t|
      color = { "active" => "yes", "inactive" => "no" }[t.status]
      status_tag I18n.t("coupon_statuses.#{t.status}"), class: color
    end
    column I18n.t("admin.columns.created_time"), :created_at
    actions name: I18n.t("admin.columns.actions")
  end

  # === Show ===
  show title: proc { |t| t.name } do
    attributes_table do
      row I18n.t("admin.columns.name"),        &:name
      row I18n.t("admin.columns.coupon_type") { |t| I18n.t("coupon_types.#{t.coupon_type}") }
      row I18n.t("admin.columns.face_value") do |t|
        t.discount? ? "#{(t.face_value * 100).to_i}折" : "¥#{t.face_value}"
      end
      row I18n.t("admin.columns.min_order_amount") do |t|
        t.min_order_amount.to_f > 0 ? "¥#{t.min_order_amount}" : I18n.t("admin.labels.no_limit")
      end
      row I18n.t("admin.columns.status") do |t|
        color = { "active" => "yes", "inactive" => "no" }[t.status]
        status_tag I18n.t("coupon_statuses.#{t.status}"), class: color
      end
      row I18n.t("admin.columns.valid_from"),  &:valid_from
      row I18n.t("admin.columns.valid_until"), &:valid_until
      row I18n.t("admin.columns.valid_days"),  &:valid_days
      row I18n.t("admin.columns.per_user_limit") do |t|
        t.per_user_limit.to_i == 0 ? I18n.t("admin.labels.no_limit") : t.per_user_limit
      end
      row I18n.t("admin.columns.category_restrictions") do |t|
        t.category_ids.empty? ? I18n.t("admin.labels.no_limit") : t.category_ids.join(", ")
      end
      row I18n.t("admin.columns.merchant_restrictions") do |t|
        t.merchant_ids.empty? ? I18n.t("admin.labels.no_limit") : t.merchant_ids.join(", ")
      end
      row I18n.t("admin.columns.grant_rules") do |t|
        rules = []
        rules << I18n.t("admin.labels.for_new_user") if t.for_new_user?
        rules << I18n.t("admin.labels.for_birthday") if t.for_birthday?
        rules << "#{I18n.t('admin.labels.min_level')} Lv#{t.min_level}" if t.min_level > 0
        rules.empty? ? I18n.t("admin.labels.manual_only") : rules.join(" / ")
      end
    end

    panel I18n.t("admin.panels.budget_control") do
      attributes_table_for coupon_template do
        row I18n.t("admin.columns.total_quota") do |t|
          t.total_quota || I18n.t("admin.labels.no_limit")
        end
        row I18n.t("admin.columns.issued_count"), &:issued_count
        row I18n.t("admin.columns.quota_used_ratio") do |t|
          t.quota_used_ratio ? "#{(t.quota_used_ratio * 100).round(1)}%" : "-"
        end
        row I18n.t("admin.columns.budget_amount") do |t|
          t.budget_amount ? "¥#{t.budget_amount}" : I18n.t("admin.labels.no_limit")
        end
        row I18n.t("admin.columns.used_amount") { |t| "¥#{t.used_amount}" }
        row I18n.t("admin.columns.budget_used_ratio") do |t|
          t.budget_used_ratio ? "#{(t.budget_used_ratio * 100).round(1)}%" : "-"
        end
        row I18n.t("admin.columns.budget_alert_threshold") do |t|
          "#{((t.budget_alert_threshold || 0.8) * 100).to_i}%"
        end
      end
    end

    panel I18n.t("admin.panels.recent_coupons") do
      table_for coupon_template.coupons.order(created_at: :desc).limit(10) do
        column I18n.t("admin.columns.code"),       &:code
        column I18n.t("admin.columns.user_id"),    &:user_id
        column I18n.t("admin.columns.grant_type") { |c| I18n.t("coupon_grant_types.#{c.grant_type}") }
        column I18n.t("admin.columns.status") do |c|
          status_tag I18n.t("coupon_item_statuses.#{c.status}")
        end
        column I18n.t("admin.columns.granted_at"), &:granted_at
        column I18n.t("admin.columns.expires_at"), &:expires_at
        column I18n.t("admin.columns.used_at"),    &:used_at
      end
    end

    active_admin_comments
  end

  # === Form ===
  form do |f|
    f.inputs I18n.t("admin.panels.basic_info") do
      f.input :name
      f.input :coupon_type, as: :select,
              collection: CouponTemplate::TYPES.map { |t| [I18n.t("coupon_types.#{t}"), t] },
              include_blank: false
      f.input :face_value, hint: I18n.t("admin.forms.face_value_hint")
      f.input :min_order_amount, hint: I18n.t("admin.forms.min_order_hint")
      f.input :description, as: :text
    end

    f.inputs I18n.t("admin.panels.grant_rules") do
      f.input :per_user_limit, hint: I18n.t("admin.forms.per_user_limit_hint")
    end

    f.inputs I18n.t("admin.panels.validity") do
      f.input :valid_from,  as: :datepicker
      f.input :valid_until, as: :datepicker
      f.input :valid_days,  hint: I18n.t("admin.forms.valid_days_hint")
    end

    f.inputs I18n.t("admin.panels.budget_control") do
      f.input :total_quota,             hint: I18n.t("admin.forms.total_quota_hint")
      f.input :budget_amount,           hint: I18n.t("admin.forms.budget_amount_hint")
      f.input :budget_alert_threshold,  hint: I18n.t("admin.forms.budget_alert_hint")
    end

    f.actions
  end

  # === Member Actions ===
  member_action :activate, method: :put do
    tmpl = CouponTemplate.find(params[:id])
    authorize! :activate, tmpl
    tmpl.activate!
    AuditService.log!(action: "activate", actor: current_admin_user, target: tmpl,
                      before: { status: "draft" }, after: { status: "active" },
                      metadata: { action_type: "coupon_template_activate" }, request: request)
    redirect_to admin_coupon_template_path(tmpl), notice: I18n.t("admin.notices.coupon_template_activated")
  rescue => e
    redirect_to admin_coupon_template_path(tmpl), alert: e.message
  end

  member_action :deactivate, method: :put do
    tmpl = CouponTemplate.find(params[:id])
    authorize! :deactivate, tmpl
    tmpl.deactivate!
    AuditService.log!(action: "deactivate", actor: current_admin_user, target: tmpl,
                      before: { status: "active" }, after: { status: "inactive" },
                      metadata: { action_type: "coupon_template_deactivate" }, request: request)
    redirect_to admin_coupon_template_path(tmpl), notice: I18n.t("admin.notices.coupon_template_deactivated")
  rescue => e
    redirect_to admin_coupon_template_path(tmpl), alert: e.message
  end

  # Issue coupons manually to a user
  member_action :issue, method: :post do
    tmpl    = CouponTemplate.find(params[:id])
    user_id = params[:user_id].to_i
    user    = User.find_by(id: user_id)

    unless user
      redirect_to admin_coupon_template_path(tmpl), alert: I18n.t("admin.alerts.user_not_found")
      return
    end

    coupon = tmpl.issue_to!(user, grant_type: "manual")
    AuditService.log!(action: "issue_coupon", actor: current_admin_user, target: tmpl,
                      metadata: { coupon_id: coupon.id, user_id: user_id }, request: request)
    redirect_to admin_coupon_template_path(tmpl),
                notice: I18n.t("admin.notices.coupon_issued", code: coupon.code)
  rescue => e
    redirect_to admin_coupon_template_path(tmpl), alert: e.message
  end

  # === Action Items ===
  action_item :activate, only: :show, if: proc { coupon_template.activatable? } do
    link_to I18n.t("admin.actions.activate_coupon_template"),
            activate_admin_coupon_template_path(coupon_template),
            method: :put,
            data: { confirm: I18n.t("admin.confirmations.activate_coupon_template") }
  end

  action_item :deactivate, only: :show, if: proc { coupon_template.deactivatable? } do
    link_to I18n.t("admin.actions.deactivate_coupon_template"),
            deactivate_admin_coupon_template_path(coupon_template),
            method: :put,
            data: { confirm: I18n.t("admin.confirmations.deactivate_coupon_template") }
  end

  # === CSV Export ===
  csv do
    column :id
    column :name
    column(:coupon_type) { |t| I18n.t("coupon_types.#{t.coupon_type}") }
    column :face_value
    column :min_order_amount
    column :status
    column :issued_count
    column :total_quota
    column :used_amount
    column :budget_amount
    column :valid_from
    column :valid_until
    column :created_at
  end
end
