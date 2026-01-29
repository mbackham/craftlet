# frozen_string_literal: true

ActiveAdmin.register Element do
  menu parent: proc { I18n.t('admin.menu.operations') }, priority: 1, label: proc { I18n.t('admin.labels.elements') }

  permit_params :name, :category, :status, :price, :oss_key, :thumbnail_key, :description

  controller do
    include Auditable
    helper AuditHelper

    after_action :audit_create, only: [:create]
    after_action :audit_update, only: [:update]
    after_action :audit_destroy, only: [:destroy]
  end

  # === Scopes ===
  scope :all, default: true
  scope :draft, label: proc { I18n.t('admin.scopes.draft') }
  scope :on_shelf, label: proc { I18n.t('admin.scopes.on_shelf') }
  scope :off_shelf, label: proc { I18n.t('admin.scopes.off_shelf') }

  # === Filters ===
  filter :name
  filter :category, as: :select, collection: Element::CATEGORIES.map { |c|
    [I18n.t("element_categories.#{c}", default: c.humanize), c]
  }
  filter :status, as: :select, collection: Element::STATUSES.map { |s|
    [I18n.t("element_statuses.#{s}", default: s.humanize), s]
  }
  filter :price
  filter :created_at
  filter :shelved_at
  filter :unshelved_at

  # === Index ===
  index do
    selectable_column
    id_column
    column I18n.t('admin.columns.name'), :name
    column I18n.t('admin.columns.category') do |el|
      I18n.t("element_categories.#{el.category}", default: el.category) if el.category
    end
    column I18n.t('admin.columns.price') do |el|
      number_to_currency(el.price, unit: '¥') if el.price
    end
    column I18n.t('admin.columns.status') do |el|
      status_color = case el.status
                     when 'on_shelf' then 'yes'
                     when 'off_shelf' then 'no'
                     else nil
                     end
      status_tag I18n.t("element_statuses.#{el.status}", default: el.status.humanize),
                 class: status_color
    end
    column I18n.t('admin.columns.shelf_time'), :shelved_at
    column I18n.t('admin.columns.created_time'), :created_at
    actions name: I18n.t('admin.columns.actions')
  end

  # === Show ===
  show title: proc { |el| I18n.t('admin.titles.element', name: el.name) } do
    attributes_table do
      row('ID') { |el| el.id }
      row(I18n.t('admin.columns.name')) { |el| el.name }
      row(I18n.t('admin.columns.category')) { |el| I18n.t("element_categories.#{el.category}", default: el.category) if el.category }
      row(I18n.t('admin.columns.price')) { |el| number_to_currency(el.price, unit: '¥') if el.price }
      row(I18n.t('admin.columns.status')) do |el|
        status_color = case el.status
                       when 'on_shelf' then 'yes'
                       when 'off_shelf' then 'no'
                       else nil
                       end
        status_tag I18n.t("element_statuses.#{el.status}", default: el.status.humanize),
                   class: status_color
      end
      row(:description) { |el| el.description }
      row('OSS Key') { |el| el.oss_key }
      row(:thumbnail_key) { |el| el.thumbnail_key }
      row(I18n.t('admin.columns.shelf_time')) { |el| l(el.shelved_at, format: :long) if el.shelved_at }
      row(:unshelved_at) { |el| l(el.unshelved_at, format: :long) if el.unshelved_at }
      row(:created_at) { |el| l(el.created_at, format: :long) if el.created_at }
      row(:updated_at) { |el| l(el.updated_at, format: :long) if el.updated_at }
    end

    panel I18n.t('admin.panels.audit_logs') do
      audit_logs = AuditLog.where(target_type: 'Element', target_id: element.id)
                           .order(created_at: :desc).limit(10)
      if audit_logs.any?
        table_for audit_logs do
          column(I18n.t('admin.columns.status')) { |log| status_tag log.action }
          column(I18n.t('admin.columns.operator')) { |log| log.actor&.email || I18n.t('admin.messages.system') }
          column(I18n.t('admin.columns.created_time')) { |log| l(log.created_at, format: :long) if log.created_at }
        end
      else
        para I18n.t('admin.messages.no_audit_logs')
      end
    end
  end

  # === Form ===
  form do |f|
    f.inputs I18n.t('admin.panels.basic_info') do
      f.input :name
      f.input :category, as: :select, collection: Element::CATEGORIES.map { |c|
        [I18n.t("element_categories.#{c}", default: c.humanize), c]
      }, include_blank: I18n.t('admin.forms.select_category')
      f.input :price
      f.input :description
    end

    f.inputs do
      f.input :oss_key, hint: I18n.t('admin.forms.oss_key_hint')
      f.input :thumbnail_key, hint: I18n.t('admin.forms.thumbnail_hint')
    end

    f.actions
  end

  # === Member Actions ===
  member_action :shelf, method: :put do
    element = Element.find(params[:id])
    
    unless element.can_shelf?
      redirect_to admin_element_path(element), alert: I18n.t('admin.alerts.status_not_allow_shelf')
      return
    end

    ActiveRecord::Base.transaction do
      old_status = element.status
      element.shelf!

      AuditService.log!(
        action: 'shelf',
        actor: current_admin_user,
        target: element,
        before: { status: old_status },
        after: { status: 'on_shelf', shelved_at: element.shelved_at },
        metadata: { action_type: 'element_shelf' },
        request: request
      )
    end

    redirect_to admin_element_path(element), notice: I18n.t('admin.notices.element_shelved')
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_element_path(element), alert: I18n.t('admin.notices.operation_failed', error: e.message)
  end

  member_action :unshelf, method: :put do
    element = Element.find(params[:id])
    
    unless element.can_unshelf?
      redirect_to admin_element_path(element), alert: I18n.t('admin.alerts.status_not_allow_unshelf')
      return
    end

    ActiveRecord::Base.transaction do
      old_status = element.status
      element.unshelf!

      AuditService.log!(
        action: 'unshelf',
        actor: current_admin_user,
        target: element,
        before: { status: old_status },
        after: { status: 'off_shelf', unshelved_at: element.unshelved_at },
        metadata: { action_type: 'element_unshelf' },
        request: request
      )
    end

    redirect_to admin_element_path(element), notice: I18n.t('admin.notices.element_unshelved')
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_element_path(element), alert: I18n.t('admin.notices.operation_failed', error: e.message)
  end

  # === Action Items ===
  action_item :shelf, only: :show, if: proc { element.can_shelf? } do
    link_to I18n.t('admin.actions.shelf'), shelf_admin_element_path(element),
            method: :put,
            data: { confirm: I18n.t('admin.confirmations.shelf_element') },
            class: 'action-item-button'
  end

  action_item :unshelf, only: :show, if: proc { element.can_unshelf? } do
    link_to I18n.t('admin.actions.unshelf'), unshelf_admin_element_path(element),
            method: :put,
            data: { confirm: I18n.t('admin.confirmations.unshelf_element') },
            class: 'action-item-button'
  end

  # === Batch Actions ===
  batch_action :shelf do |ids|
    batch_action_collection.find(ids).each do |element|
      next unless element.can_shelf?
      element.shelf!
    end
    redirect_to collection_path, notice: "#{I18n.t('admin.messages.batch_shelved')} #{ids.size}"
  end

  batch_action :unshelf do |ids|
    batch_action_collection.find(ids).each do |element|
      next unless element.can_unshelf?
      element.unshelf!
    end
    redirect_to collection_path, notice: "#{I18n.t('admin.messages.batch_unshelved')} #{ids.size}"
  end

  # === CSV Export ===
  csv do
    column :id
    column :name
    column :category
    column :price
    column :status
    column :oss_key
    column :shelved_at
    column :unshelved_at
    column :created_at
  end
end
