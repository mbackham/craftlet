# frozen_string_literal: true

ActiveAdmin.register CouponBudgetAlert do
  menu parent: "marketing_menu", priority: 3,
       label: proc { I18n.t("admin.labels.coupon_budget_alerts") }

  actions :index, :show

  # === Filters ===
  filter :coupon_template
  filter :alert_type, as: :select,
         collection: CouponBudgetAlert::ALERT_TYPES.map { |t| [I18n.t("coupon_alert_types.#{t}"), t] }
  filter :status, as: :select,
         collection: CouponBudgetAlert::STATUSES.map { |s| [I18n.t("coupon_alert_statuses.#{s}"), s] }
  filter :created_at

  # === Scopes ===
  scope :all, default: true
  scope proc { I18n.t("coupon_alert_statuses.pending") },      :pending
  scope proc { I18n.t("coupon_alert_statuses.acknowledged") }, :acknowledged

  # === Index ===
  index do
    selectable_column
    id_column
    column I18n.t("admin.columns.template") do |a|
      link_to a.coupon_template.name, admin_coupon_template_path(a.coupon_template)
    end
    column I18n.t("admin.columns.alert_type") { |a| I18n.t("coupon_alert_types.#{a.alert_type}") }
    column I18n.t("admin.columns.current_ratio") do |a|
      a.current_ratio ? "#{(a.current_ratio * 100).round(1)}%" : "-"
    end
    column I18n.t("admin.columns.status") do |a|
      color = a.status == "pending" ? "no" : "yes"
      status_tag I18n.t("coupon_alert_statuses.#{a.status}"), class: color
    end
    column I18n.t("admin.columns.created_time"), :created_at
    actions name: I18n.t("admin.columns.actions")
  end

  # === Show ===
  show do
    attributes_table do
      row I18n.t("admin.columns.template") do |a|
        link_to a.coupon_template.name, admin_coupon_template_path(a.coupon_template)
      end
      row I18n.t("admin.columns.alert_type") { |a| I18n.t("coupon_alert_types.#{a.alert_type}") }
      row I18n.t("admin.columns.current_ratio") do |a|
        a.current_ratio ? "#{(a.current_ratio * 100).round(1)}%" : "-"
      end
      row I18n.t("admin.columns.status") do |a|
        color = a.status == "pending" ? "no" : "yes"
        status_tag I18n.t("coupon_alert_statuses.#{a.status}"), class: color
      end
      row I18n.t("admin.columns.acknowledged_by") do |a|
        a.acknowledged_by&.email
      end
      row I18n.t("admin.columns.acknowledged_at"), &:acknowledged_at
      row :created_at
    end
  end

  # === Member Actions ===
  member_action :acknowledge, method: :put do
    alert = CouponBudgetAlert.find(params[:id])
    alert.acknowledge!(current_admin_user)
    redirect_to admin_coupon_budget_alert_path(alert),
                notice: I18n.t("admin.notices.coupon_alert_acknowledged")
  rescue => e
    redirect_to admin_coupon_budget_alert_path(alert), alert: e.message
  end

  # === Action Items ===
  action_item :acknowledge, only: :show, if: proc { coupon_budget_alert.status == "pending" } do
    link_to I18n.t("admin.actions.acknowledge_alert"),
            acknowledge_admin_coupon_budget_alert_path(coupon_budget_alert),
            method: :put,
            data: { confirm: I18n.t("admin.confirmations.acknowledge_alert") }
  end

  # === Batch Actions ===
  batch_action :acknowledge do |ids|
    batch_action_collection.find(ids).each do |alert|
      alert.acknowledge!(current_admin_user) if alert.status == "pending"
    end
    redirect_to collection_path, notice: I18n.t("admin.messages.batch_acknowledged", count: ids.size)
  end
end
