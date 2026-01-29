# frozen_string_literal: true

ActiveAdmin.register User do
  menu parent: proc { I18n.t('admin.menu.rbac') }, priority: 1

  permit_params :email, :phone, :nickname, :status, :password, :password_confirmation,
                admin_role_ids: []

  controller do
    include Auditable
    
    after_action :audit_create, only: [:create]
    after_action :audit_update, only: [:update]
    after_action :audit_destroy, only: [:destroy]
  end

  scope :all, default: true
  scope :active, label: proc { I18n.t('admin.scopes.active_users') } do |scope|
    scope.where(status: 'active')
  end
  scope :disabled, label: proc { I18n.t('admin.scopes.disabled_users') } do |scope|
    scope.where(status: 'disabled')
  end
  scope :with_admin_role, label: proc { I18n.t('admin.scopes.has_admin_role') } do |scope|
    scope.joins(:admin_roles).distinct
  end

  index do
    selectable_column
    id_column
    column :email
    column :phone
    column :nickname
    column :status do |user|
      label = I18n.t("user_statuses.#{user.status}", default: user.status)
      status_tag label, class: user.status == 'active' ? 'yes' : 'no'
    end
    column I18n.t('admin.columns.business_role') do |user|
      user.roles.pluck(:role_type).join(', ').presence || '-'
    end
    column I18n.t('admin.columns.admin_role') do |user|
      user.admin_roles.pluck(:name).join(', ').presence || '-'
    end
    column :created_at
    actions name: I18n.t('admin.columns.actions')
  end

  filter :email
  filter :phone
  filter :nickname
  filter :status, as: :select, collection: -> {
    [
      [I18n.t('user_statuses.active'), 'active'],
      [I18n.t('user_statuses.disabled'), 'disabled']
    ]
  }
  filter :created_at

  show do
    attributes_table do
      row :id
      row :email
      row :phone
      row :nickname
      row :status do |user|
        label = I18n.t("user_statuses.#{user.status}", default: user.status)
        status_tag label, class: user.status == 'active' ? 'yes' : 'no'
      end
      row :avatar_key
      row :disabled_at
      row :disabled_reason
      row :created_at
      row :updated_at
    end

    panel I18n.t('admin.panels.business_roles') do
      table_for user.roles do
        column I18n.t('admin.columns.business_role') do |role|
          role.role_type
        end
        column :status do |role|
          label = role.is_active ? I18n.t('active_admin.status_tag.yes') : I18n.t('active_admin.status_tag.no')
          status_tag(label, class: role.is_active ? 'yes' : 'no')
        end
        column :created_at
      end
    end

    panel I18n.t('admin.panels.admin_roles') do
      if user.admin_roles.any?
        table_for user.admin_roles do
          column :code do |role|
            link_to role.code, admin_admin_role_path(role)
          end
          column :name
          column I18n.t('admin.panels.assigned_permissions') do |role|
            role.admin_permissions.pluck(:code).join(', ')
          end
        end
      else
        para I18n.t('admin.messages.no_admin_roles')
      end
    end

    panel I18n.t('admin.panels.recent_audit_logs') do
      table_for user.audit_logs.order(created_at: :desc).limit(10) do
        column :action do |log|
          action_badge(log.action)
        end
        column :target_type
        column :target_id
        column :ip
        column :created_at
        column I18n.t('admin.actions.view') do |log|
          link_to I18n.t('admin.actions.view'), admin_audit_log_path(log)
        end
      end
    end
  end

  form do |f|
    f.inputs I18n.t('admin.panels.basic_info') do
      f.input :email
      f.input :phone
      f.input :nickname
      f.input :status, as: :select, collection: ['active', 'disabled'], include_blank: false
    end

    f.inputs I18n.t('admin.panels.password') do
      f.input :password, hint: I18n.t('admin.forms.password_hint')
      f.input :password_confirmation
    end

    f.inputs I18n.t('admin.panels.admin_role_assignment') do
      f.input :admin_roles,
              as: :check_boxes,
              collection: AdminRole.all.order(:code),
              label_method: ->(r) { "#{r.name} (#{r.code})" },
              hint: I18n.t('admin.forms.role_assignment_hint')
    end

    f.actions
  end

  # Member actions
  member_action :activate, method: :put do
    user = User.find(params[:id])
    
    service = Users::UnsuspendService.new(
      user: user,
      admin_user: current_admin_user,
      request: request
    ).call

    if service.success?
      redirect_to admin_user_path(user), notice: I18n.t('admin.notices.user_activated')
    else
      redirect_to admin_user_path(user), alert: I18n.t('admin.notices.operation_failed', error: service.error)
    end
  end

  member_action :deactivate, method: :put do
    user = User.find(params[:id])
    reason = params[:reason] || 'Admin deactivation'
    
    service = Users::SuspendService.new(
      user: user,
      admin_user: current_admin_user,
      reason: reason,
      request: request
    ).call

    if service.success?
      redirect_to admin_user_path(user), notice: I18n.t('admin.notices.user_deactivated')
    else
      redirect_to admin_user_path(user), alert: I18n.t('admin.notices.operation_failed', error: service.error)
    end
  end

  action_item :activate, only: :show, if: proc { user.status == 'disabled' } do
    link_to I18n.t('admin.actions.activate'), activate_admin_user_path(user), method: :put, 
            data: { confirm: I18n.t('admin.confirmations.activate_user') }
  end

  action_item :deactivate, only: :show, if: proc { user.status == 'active' } do
    link_to I18n.t('admin.actions.deactivate'), deactivate_admin_user_path(user), method: :put,
            data: { confirm: I18n.t('admin.confirmations.deactivate_user') }
  end
end
