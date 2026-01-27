# frozen_string_literal: true

ActiveAdmin.register AdminPermission do
  menu parent: 'RBAC管理', priority: 3

  # Read-only resource (permissions are code-managed via seeds)
  actions :index, :show

  index do
    selectable_column
    id_column
    column :code do |permission|
      content_tag(:code, permission.code)
    end
    column :name
    column '关联角色数' do |permission|
      permission.admin_roles.count
    end
    column :created_at
    actions
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

    panel '拥有此权限的角色' do
      table_for admin_permission.admin_roles do
        column :id
        column :code do |role|
          link_to role.code, admin_admin_role_path(role)
        end
        column :name do |role|
          link_to role.name, admin_admin_role_path(role)
        end
        column '用户数' do |role|
          role.users.count
        end
      end
    end
  end
end
