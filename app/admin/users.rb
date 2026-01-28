# frozen_string_literal: true

ActiveAdmin.register User do
  menu parent: 'RBAC管理', priority: 1

  permit_params :email, :phone, :nickname, :status, :password, :password_confirmation,
                admin_role_ids: []

  controller do
    include Auditable
    
    after_action :audit_create, only: [:create]
    after_action :audit_update, only: [:update]
    after_action :audit_destroy, only: [:destroy]
  end

  scope :all, default: true
  scope('活跃用户') { |scope| scope.where(status: 'active') }
  scope('已禁用') { |scope| scope.where(status: 'disabled') }
  scope('有管理角色') { |scope| scope.joins(:admin_roles).distinct }

  index do
    selectable_column
    id_column
    column :email
    column :phone
    column :nickname
    column :status do |user|
      label = user.status == 'active' ? '活跃' : '已禁用'
      status_tag label, class: user.status == 'active' ? 'yes' : 'no'
    end
    column '业务角色' do |user|
      user.roles.pluck(:role_type).join(', ').presence || '-'
    end
    column '管理角色' do |user|
      user.admin_roles.pluck(:name).join(', ').presence || '-'
    end
    column :created_at
    actions name: '操作'
  end

  filter :email
  filter :phone
  filter :nickname
  filter :status, as: :select, collection: [['活跃', 'active'], ['已禁用', 'disabled']]
  # Disabled: admin_roles filter - use Scopes instead (有管理角色)
  filter :created_at

  show do
    attributes_table do
      row :id
      row :email
      row :phone
      row :nickname
      row :status do |user|
        label = user.status == 'active' ? '活跃' : '已禁用'
        status_tag label, class: user.status == 'active' ? 'yes' : 'no'
      end
      row :avatar_key
      row :disabled_at
      row :disabled_reason
      row :created_at
      row :updated_at
    end

    panel '业务角色' do
      table_for user.roles do
        column('角色类型') { |role| role.role_type }
        column('是否激活') do |role|
          status_tag(role.is_active ? '是' : '否', class: role.is_active ? 'yes' : 'no')
        end
        column :created_at
      end
    end

    panel '管理角色' do
      if user.admin_roles.any?
        table_for user.admin_roles do
          column :code do |role|
            link_to role.code, admin_admin_role_path(role)
          end
          column :name
          column '权限' do |role|
            role.admin_permissions.pluck(:code).join(', ')
          end
        end
      else
        para '无管理角色'
      end
    end

    panel '最近审计日志' do
      table_for user.audit_logs.order(created_at: :desc).limit(10) do
        column :action do |log|
          action_badge(log.action)
        end
        column :target_type
        column :target_id
        column :ip
        column :created_at
        column :详情 do |log|
          link_to '查看', admin_audit_log_path(log)
        end
      end
    end
  end

  form do |f|
    f.inputs '基本信息' do
      f.input :email
      f.input :phone
      f.input :nickname
      f.input :status, as: :select, collection: ['active', 'disabled'], include_blank: false
    end

    f.inputs '密码' do
      f.input :password, hint: '留空则不修改密码'
      f.input :password_confirmation
    end

    f.inputs '管理角色分配' do
      f.input :admin_roles,
              as: :check_boxes,
              collection: AdminRole.all.order(:code),
              label_method: ->(r) { "#{r.name} (#{r.code})" },
              hint: '选择要分配给此用户的管理角色'
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
      redirect_to admin_user_path(user), notice: '用户已激活'
    else
      redirect_to admin_user_path(user), alert: "操作失败: #{service.error}"
    end
  end

  member_action :deactivate, method: :put do
    user = User.find(params[:id])
    reason = params[:reason] || '管理员停用'
    
    service = Users::SuspendService.new(
      user: user,
      admin_user: current_admin_user,
      reason: reason,
      request: request
    ).call

    if service.success?
      redirect_to admin_user_path(user), notice: '用户已停用'
    else
      redirect_to admin_user_path(user), alert: "操作失败: #{service.error}"
    end
  end

  action_item :activate, only: :show, if: proc { user.status == 'disabled' } do
    link_to '激活用户', activate_admin_user_path(user), method: :put, 
            data: { confirm: '确认激活此用户？' }
  end

  action_item :deactivate, only: :show, if: proc { user.status == 'active' } do
    link_to '停用用户', deactivate_admin_user_path(user), method: :put,
            data: { confirm: '确认停用此用户？\n请输入停用原因：', 
                    prompt: '停用原因' }
  end
end
