# frozen_string_literal: true

ActiveAdmin.register AuditLog do
  menu parent: proc { I18n.t('admin.menu.rbac') }, priority: 4, label: proc { I18n.t('admin.labels.audit_logs') }

  controller do
    helper AuditHelper
  end

  # Read-only resource
  actions :index, :show

  # Custom scopes for common queries
  scope :all, default: true
  scope :today, label: proc { I18n.t('admin.scopes.today') } do |scope|
    scope.where('created_at >= ?', Time.current.beginning_of_day)
  end
  scope :this_week, label: proc { I18n.t('admin.scopes.this_week') } do |scope|
    scope.where('created_at >= ?', Time.current.beginning_of_week)
  end
  scope :create_actions, label: proc { I18n.t('admin.scopes.create_action') } do |scope|
    scope.where(action: 'create')
  end
  scope :update_actions, label: proc { I18n.t('admin.scopes.update_action') } do |scope|
    scope.where(action: 'update')
  end
  scope :destroy_actions, label: proc { I18n.t('admin.scopes.delete_action') } do |scope|
    scope.where(action: 'destroy')
  end

  index do
    selectable_column
    id_column
    column I18n.t('admin.columns.status'), sortable: :action do |log|
      action_label = I18n.t("audit_actions.#{log.action}", default: log.action.to_s.humanize)
      action_color = case log.action.to_s
                     when 'create' then 'yes'
                     when 'update' then 'warning'
                     when 'destroy' then 'error'
                     when 'approve' then 'yes'
                     when 'reject' then 'error'
                     when 'suspend' then 'no'
                     when 'unsuspend' then 'yes'
                     when 'activate' then 'yes'
                     when 'deactivate' then 'no'
                     else nil
                     end
      status_tag(action_label, class: action_color)
    end
    column I18n.t('admin.columns.operator') do |log|
      if log.actor
        if log.actor.is_a?(AdminUser)
          link_to log.actor.email, admin_admin_user_path(log.actor)
        else
          link_to log.actor.email, admin_user_path(log.actor)
        end
      else
        content_tag(:span, I18n.t('admin.messages.system'), class: 'system')
      end
    end
    column I18n.t('admin.columns.target') do |log|
      audit_target_link(log)
    end
    column I18n.t('admin.columns.ip_address'), :ip
    column I18n.t('admin.columns.created_time') do |log|
      l(log.created_at, format: :long) if log.created_at
    end
    actions name: I18n.t('admin.columns.actions')
  end

  filter :action, as: :select, collection: -> {
    AuditLog.distinct.pluck(:action).compact.sort
  }
  filter :target_type, as: :select, collection: -> {
    AuditLog.distinct.pluck(:target_type).compact.sort
  }
  filter :ip
  filter :created_at

  show do
    attributes_table do
      row 'ID', :id
      row I18n.t('admin.columns.status') do |log|
        status_tag(log.action, class: log.action.to_s.downcase)
      end
      row I18n.t('admin.columns.operator') do |log|
        if log.actor
          if log.actor.is_a?(AdminUser)
            link_to log.actor.email, admin_admin_user_path(log.actor)
          else
            link_to log.actor.email, admin_user_path(log.actor)
          end
        else
          content_tag(:span, I18n.t('admin.messages.system'), class: 'system')
        end
      end
      row :target_type
      row :target_id
      row I18n.t('admin.columns.target') do |log|
        audit_target_link(log)
      end
      row :request_id
      row I18n.t('admin.columns.ip_address'), :ip
      row 'User Agent', :user_agent
      row :created_at
      row :updated_at
    end

    panel I18n.t('admin.panels.change_details') do
      if audit_log.before.present? || audit_log.after.present?
        div do
          h3 I18n.t('admin.panels.change_comparison')
          audit_diff(audit_log.before, audit_log.after)
        end
      else
        para I18n.t('admin.messages.no_changes')
      end
    end

    panel I18n.t('admin.panels.before_data') do
      if audit_log.before.present?
        format_audit_json(audit_log.before)
      else
        para I18n.t('admin.messages.no_data')
      end
    end

    panel I18n.t('admin.panels.after_data') do
      if audit_log.after.present?
        format_audit_json(audit_log.after)
      else
        para I18n.t('admin.messages.no_data')
      end
    end

    panel 'Metadata' do
      if audit_log.metadata.present?
        format_audit_json(audit_log.metadata)
      else
        para I18n.t('admin.messages.no_data')
      end
    end
  end

  # Custom CSV export with selected fields
  csv do
    column :id
    column :action
    column(I18n.t('admin.columns.operator')) { |log| log.actor&.email || I18n.t('admin.messages.system') }
    column :target_type
    column :target_id
    column :ip
    column :request_id
    column :created_at
  end
end
