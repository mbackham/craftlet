# frozen_string_literal: true

ActiveAdmin.register Faq do
  menu parent: "content_menu", priority: 4, label: proc { I18n.t("admin.labels.faqs") }

  permit_params :question_zh, :question_en, :answer_zh, :answer_en, :faq_category_id, :sort, :is_active

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
  filter :faq_category, as: :select, collection: proc {
    FaqCategory.ordered.map { |c| [c.localized_name, c.id] }
  }
  filter :is_active
  filter :created_at

  # === Index ===
  index do
    selectable_column
    id_column
    column I18n.t("admin.columns.category") do |faq|
      faq.faq_category&.localized_name
    end
    column I18n.t("admin.columns.question") do |faq|
      truncate(faq.localized_question, length: 60)
    end
    column I18n.t("admin.columns.sort"), :sort
    column I18n.t("admin.columns.is_active") do |faq|
      status_tag(faq.is_active ? I18n.t("active_admin.status_tag.yes") : I18n.t("active_admin.status_tag.no"),
                 class: faq.is_active ? "yes" : "no")
    end
    column I18n.t("admin.columns.created_time"), :created_at
    actions name: I18n.t("admin.columns.actions")
  end

  # === Show ===
  show title: proc { |f| truncate(f.localized_question, length: 40) } do
    attributes_table do
      row("ID") { |f| f.id }
      row(I18n.t("admin.columns.category")) { |f| f.faq_category&.localized_name }
      row(I18n.t("admin.columns.question_zh")) { |f| f.question["zh-CN"] }
      row(I18n.t("admin.columns.question_en")) { |f| f.question["en"] }
      row(I18n.t("admin.columns.answer_zh")) { |f| simple_format(f.answer["zh-CN"]) if f.answer["zh-CN"].present? }
      row(I18n.t("admin.columns.answer_en")) { |f| simple_format(f.answer["en"]) if f.answer["en"].present? }
      row(I18n.t("admin.columns.sort")) { |f| f.sort }
      row(I18n.t("admin.columns.is_active")) do |f|
        status_tag(f.is_active ? I18n.t("active_admin.status_tag.yes") : I18n.t("active_admin.status_tag.no"),
                   class: f.is_active ? "yes" : "no")
      end
      row(:created_at) { |f| l(f.created_at, format: :long) }
      row(:updated_at) { |f| l(f.updated_at, format: :long) }
    end
  end

  # === Form ===
  form do |f|
    f.inputs I18n.t("admin.panels.multilingual_question") do
      f.input :question_zh, as: :text, label: I18n.t("admin.columns.question_zh"), input_html: { rows: 3 }
      f.input :question_en, as: :text, label: I18n.t("admin.columns.question_en"), input_html: { rows: 3 }
    end

    f.inputs I18n.t("admin.panels.multilingual_answer") do
      f.input :answer_zh, as: :text, label: I18n.t("admin.columns.answer_zh"), input_html: { rows: 6 }
      f.input :answer_en, as: :text, label: I18n.t("admin.columns.answer_en"), input_html: { rows: 6 }
    end

    f.inputs I18n.t("admin.panels.basic_info") do
      f.input :faq_category, as: :select, collection: FaqCategory.ordered.map { |c| [c.localized_name, c.id] },
              include_blank: I18n.t("admin.forms.select_category")
      f.input :sort
      f.input :is_active
    end

    f.actions
  end

  # === CSV Export ===
  csv do
    column :id
    column(:category) { |f| f.faq_category&.localized_name }
    column(:question) { |f| f.localized_question }
    column(:answer) { |f| f.localized_answer }
    column :sort
    column :is_active
    column :created_at
  end
end
