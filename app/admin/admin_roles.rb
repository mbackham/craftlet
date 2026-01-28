# frozen_string_literal: true

ActiveAdmin.register AdminRole do
  menu parent: 'RBAC管理', priority: 2, label: '管理角色'

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
    column '权限数' do |role|
      role.admin_permissions.count
    end
    column '用户数' do |role|
      role.users.count
    end
    column :created_at
    actions name: '操作'
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

    panel '已分配的权限' do
      table_for admin_role.admin_permissions.order(:code) do
        column :code do |permission|
          link_to permission.code, admin_admin_permission_path(permission)
        end
        column :name
      end
    end

    panel '拥有此角色的用户' do
      table_for admin_role.users.order(:email) do
        column :id
        column :email do |user|
          link_to user.email, admin_user_path(user)
        end
        column :phone
        column :status do |u|
          u.status == 'active' ? '活跃' : '已禁用'
        end
        column :created_at
      end
    end
  end

  form do |f|
    f.inputs '角色信息' do
      f.input :code, hint: '角色代码，英文小写+下划线，如: content_manager'
      f.input :name, hint: '角色名称，如: 内容管理员'
    end

    f.inputs '权限分配' do
      f.input :admin_permissions,
              as: :check_boxes,
              collection: AdminPermission.all.order(:code),
              label_method: ->(p) { "#{p.name} (#{p.code})" }
    end

    f.actions
  end
end
