# frozen_string_literal: true

ActiveAdmin.register AdminRole do
  menu parent: proc { I18n.t('admin.menu.rbac') }, priority: 2, label: proc { I18n.t('admin.labels.admin_roles') }

  permit_params :name, :code, admin_permission_ids: []

  controller do
    include Auditable
    
    after_action :audit_create, only: [:create]
    after_action :audit_update, only: [:update]
    after_action :audit_destroy, only: [:destroy]
  end

  index do
    selectable_column
    id_column
    column :code do |role|
      content_tag(:code, role.code)
    end
    column :name
    column I18n.t('admin.columns.permission_count') do |role|
      role.admin_permissions.count
    end
    column I18n.t('admin.columns.user_count') do |role|
      role.users.count
    end
    column :created_at
    actions name: I18n.t('admin.columns.actions')
  end

  filter :code
  filter :name
  filter :created_at

  show do
    attributes_table do
      row :id
      row :code do |role|
        content_tag(:code, role.code)
      end
      row :name
      row :created_at
      row :updated_at
    end

    panel I18n.t('admin.panels.assigned_permissions') do
      table_for admin_role.admin_permissions.order(:code) do
        column :code do |permission|
          link_to permission.code, admin_admin_permission_path(permission)
        end
        column :name
      end
    end

    panel I18n.t('admin.panels.users_with_role') do
      table_for admin_role.users.order(:email) do
        column :id
        column :email do |user|
          link_to user.email, admin_user_path(user)
        end
        column :phone
        column :status do |u|
          I18n.t("user_statuses.#{u.status}", default: u.status)
        end
        column :created_at
      end
    end
  end

  form do |f|
    f.inputs I18n.t('admin.panels.role_info') do
      f.input :code, hint: I18n.t('admin.forms.role_code_hint')
      f.input :name, hint: I18n.t('admin.forms.role_name_hint')
    end

    f.inputs I18n.t('admin.panels.permission_assignment') do
      f.input :admin_permissions,
              as: :check_boxes,
              collection: AdminPermission.all.order(:code),
              label_method: ->(p) { "#{p.name} (#{p.code})" }
    end

    f.actions
  end
end
