# frozen_string_literal: true

ActiveAdmin.register FaqCategory do
  menu parent: "content_menu", priority: 3, label: proc { I18n.t("admin.labels.faq_categories") }

  permit_params :name_zh, :name_en, :slug, :sort, :is_active

  controller do
    include Auditable
    helper AuditHelper

    after_action :audit_create, only: [:create]
    after_action :audit_update, only: [:update]
    after_action :audit_destroy, only: [:destroy]


  end

  # === Scopes ===
  scope :all, default: true
  scope proc { I18n.t("admin.scopes.active_items") }, :active

  # === Filters ===
  filter :slug
  filter :is_active
  filter :created_at

  # === Index ===
  index do
    selectable_column
    id_column
    column I18n.t("admin.columns.name_zh") do |cat|
      cat.name["zh-CN"]
    end
    column I18n.t("admin.columns.name_en") do |cat|
      cat.name["en"]
    end
    column I18n.t("admin.columns.slug"), :slug
    column I18n.t("admin.columns.sort"), :sort
    column I18n.t("admin.columns.is_active") do |cat|
      status_tag(cat.is_active ? I18n.t("active_admin.status_tag.yes") : I18n.t("active_admin.status_tag.no"),
                 class: cat.is_active ? "yes" : "no")
    end
    column I18n.t("admin.columns.faq_count") do |cat|
      cat.faqs.count
    end
    column I18n.t("admin.columns.created_time"), :created_at
    actions name: I18n.t("admin.columns.actions")
  end

  # === Show ===
  show title: proc { |c| c.localized_name } do
    attributes_table do
      row("ID") { |c| c.id }
      row(I18n.t("admin.columns.name_zh")) { |c| c.name["zh-CN"] }
      row(I18n.t("admin.columns.name_en")) { |c| c.name["en"] }
      row(I18n.t("admin.columns.slug")) { |c| c.slug }
      row(I18n.t("admin.columns.sort")) { |c| c.sort }
      row(I18n.t("admin.columns.is_active")) do |c|
        status_tag(c.is_active ? I18n.t("active_admin.status_tag.yes") : I18n.t("active_admin.status_tag.no"),
                   class: c.is_active ? "yes" : "no")
      end
      row(:created_at) { |c| l(c.created_at, format: :long) }
    end

    panel I18n.t("admin.panels.faqs_in_category") do
      if faq_category.faqs.any?
        table_for faq_category.faqs.ordered do
          column("ID") { |f| link_to f.id, admin_faq_path(f) }
          column(I18n.t("admin.columns.question")) { |f| f.localized_question }
          column(I18n.t("admin.columns.sort")) { |f| f.sort }
          column(I18n.t("admin.columns.is_active")) do |f|
            status_tag(f.is_active ? I18n.t("active_admin.status_tag.yes") : I18n.t("active_admin.status_tag.no"),
                       class: f.is_active ? "yes" : "no")
          end
        end
      else
        para I18n.t("admin.messages.no_faqs")
      end
    end
  end

  # === Form ===
  form do |f|
    f.inputs I18n.t("admin.panels.multilingual_name") do
      f.input :name_zh, as: :string, label: I18n.t("admin.columns.name_zh")
      f.input :name_en, as: :string, label: I18n.t("admin.columns.name_en")
    end

    f.inputs I18n.t("admin.panels.basic_info") do
      f.input :slug, hint: I18n.t("admin.forms.slug_hint")
      f.input :sort
      f.input :is_active
    end

    f.actions
  end

  # === CSV Export ===
  csv do
    column :id
    column(:name_zh) { |c| c.name["zh-CN"] }
    column(:name_en) { |c| c.name["en"] }
    column :slug
    column :sort
    column :is_active
    column :created_at
  end
end
