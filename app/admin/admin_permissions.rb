# frozen_string_literal: true

ActiveAdmin.register AdminPermission do
  menu parent: proc { I18n.t('admin.menu.rbac') }, priority: 3, label: proc { I18n.t('admin.labels.admin_permissions') }

  # Read-only resource (permissions are code-managed via seeds)
  actions :index, :show

  index do
    selectable_column
    id_column
    column :code do |permission|
      content_tag(:code, permission.code)
    end
    column :name
    column I18n.t('admin.columns.related_roles') do |permission|
      permission.admin_roles.count
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
      row :code do |permission|
        content_tag(:code, permission.code)
      end
      row :name
      row :created_at
      row :updated_at
    end

    panel I18n.t('admin.panels.roles_with_permission') do
      table_for admin_permission.admin_roles do
        column :id
        column :code do |role|
          link_to role.code, admin_admin_role_path(role)
        end
        column :name do |role|
          link_to role.name, admin_admin_role_path(role)
        end
        column I18n.t('admin.columns.user_count') do |role|
          role.users.count
        end
      end
    end
  end
end
