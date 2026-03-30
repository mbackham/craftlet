# frozen_string_literal: true

ActiveAdmin.register Coupon do
  menu parent: "marketing_menu", priority: 2,
       label: proc { I18n.t("admin.labels.coupons") }

  actions :index, :show

  # === Filters ===
  filter :coupon_template, as: :select, collection: -> { CouponTemplate.all.map { |t| [t.name, t.id] } }
  filter :user_id, as: :numeric
  filter :code
  filter :status, as: :select,
         collection: Coupon::STATUSES.map { |s| [I18n.t("coupon_item_statuses.#{s}"), s] }
  filter :grant_type, as: :select,
         collection: Coupon::GRANT_TYPES.map { |g| [I18n.t("coupon_grant_types.#{g}"), g] }
  filter :granted_at
  filter :expires_at
  filter :used_at

  # === Scopes ===
  scope :all, default: true
  scope proc { I18n.t("coupon_item_statuses.unused") }, :unused
  scope proc { I18n.t("coupon_item_statuses.used") },   :used
  scope proc { I18n.t("coupon_item_statuses.expired") }, :expired

  # === Index ===
  index do
    selectable_column
    id_column
    column I18n.t("admin.columns.template") do |c|
      link_to c.coupon_template.name, admin_coupon_template_path(c.coupon_template)
    end
    column I18n.t("admin.columns.code"), :code
    column I18n.t("admin.columns.user_id"), :user_id
    column I18n.t("admin.columns.grant_type") { |c| I18n.t("coupon_grant_types.#{c.grant_type}") }
    column I18n.t("admin.columns.status") do |c|
      color = { "unused" => "yes", "used" => nil, "expired" => "no" }[c.status]
      status_tag I18n.t("coupon_item_statuses.#{c.status}"), class: color
    end
    column I18n.t("admin.columns.discount_amount") do |c|
      c.discount_amount ? "¥#{c.discount_amount}" : "-"
    end
    column I18n.t("admin.columns.granted_at"), :granted_at
    column I18n.t("admin.columns.expires_at"), :expires_at
    actions name: I18n.t("admin.columns.actions")
  end

  # === Show ===
  show title: proc { |c| c.code } do
    attributes_table do
      row I18n.t("admin.columns.template") do |c|
        link_to c.coupon_template.name, admin_coupon_template_path(c.coupon_template)
      end
      row I18n.t("admin.columns.code"),       &:code
      row I18n.t("admin.columns.user_id"),    &:user_id
      row I18n.t("admin.columns.grant_type") { |c| I18n.t("coupon_grant_types.#{c.grant_type}") }
      row I18n.t("admin.columns.status") do |c|
        color = { "unused" => "yes", "used" => nil, "expired" => "no" }[c.status]
        status_tag I18n.t("coupon_item_statuses.#{c.status}"), class: color
      end
      row I18n.t("admin.columns.granted_at"),      &:granted_at
      row I18n.t("admin.columns.expires_at"),      &:expires_at
      row I18n.t("admin.columns.used_at"),         &:used_at
      row I18n.t("admin.columns.order_id"),        &:order_id
      row I18n.t("admin.columns.discount_amount") { |c| c.discount_amount ? "¥#{c.discount_amount}" : "-" }
    end
  end

  # === CSV Export ===
  csv do
    column :id
    column :code
    column(:coupon_template) { |c| c.coupon_template.name }
    column :user_id
    column(:grant_type) { |c| I18n.t("coupon_grant_types.#{c.grant_type}") }
    column(:status) { |c| I18n.t("coupon_item_statuses.#{c.status}") }
    column :granted_at
    column :expires_at
    column :used_at
    column :order_id
    column :discount_amount
  end
end
