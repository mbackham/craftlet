# frozen_string_literal: true

ActiveAdmin.register AuditLog do
  menu parent: 'RBAC管理', priority: 4, label: '审计日志'

  controller do
    helper AuditHelper
  end

  # Read-only resource
  actions :index, :show

  # Custom scopes for common queries
  scope :all, default: true
  scope('今天') { |scope| scope.where('created_at >= ?', Time.current.beginning_of_day) }
  scope('本周') { |scope| scope.where('created_at >= ?', Time.current.beginning_of_week) }
  scope('创建操作') { |scope| scope.where(action: 'create') }
  scope('更新操作') { |scope| scope.where(action: 'update') }
  scope('删除操作') { |scope| scope.where(action: 'destroy') }

  index do
    selectable_column
    id_column
    column '状态', sortable: :action do |log|
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
    column '操作人' do |log|
      if log.actor
        if log.actor.is_a?(AdminUser)
          link_to log.actor.email, admin_admin_user_path(log.actor)
        else
          link_to log.actor.email, admin_user_path(log.actor)
        end
      else
        content_tag(:span, '系统', class: 'system')
      end
    end
    column '目标' do |log|
      audit_target_link(log)
    end
    column 'IP地址', :ip
    column '创建时间' do |log|
      l(log.created_at, format: :long) if log.created_at
    end
    actions name: '操作'
  end

  filter :action, as: :select, collection: -> {
    AuditLog.distinct.pluck(:action).compact.sort
  }
  # Disabled: actor_id filter causes UUID/bigint type mismatch
  # filter :actor_id, as: :select, collection: -> {
  #   User.joins(:audit_logs).distinct.pluck(:email, :id)
  # }, label: '操作人'
  filter :target_type, as: :select, collection: -> {
    AuditLog.distinct.pluck(:target_type).compact.sort
  }
  filter :ip
  filter :created_at

  show do
    attributes_table do
      row 'ID', :id
      row '操作' do |log|
        status_tag(log.action, class: log.action.to_s.downcase)
      end
      row '操作人' do |log|
        if log.actor
          if log.actor.is_a?(AdminUser)
            link_to log.actor.email, admin_admin_user_path(log.actor)
          else
            link_to log.actor.email, admin_user_path(log.actor)
          end
        else
          content_tag(:span, '系统', class: 'system')
        end
      end
      row '目标类型', :target_type
      row '目标ID', :target_id
      row '目标' do |log|
        audit_target_link(log)
      end
      row '请求ID', :request_id
      row 'IP地址', :ip
      row 'User Agent', :user_agent
      row '创建时间', :created_at
      row '更新时间', :updated_at
    end

    panel '变更详情' do
      if audit_log.before.present? || audit_log.after.present?
        div do
          h3 '变更对比'
          audit_diff(audit_log.before, audit_log.after)
        end
      else
        para '无变更数据'
      end
    end

    panel '变更前数据 (Before)' do
      if audit_log.before.present?
        format_audit_json(audit_log.before)
      else
        para '无'
      end
    end

    panel '变更后数据 (After)' do
      if audit_log.after.present?
        format_audit_json(audit_log.after)
      else
        para '无'
      end
    end

    panel 'Metadata' do
      if audit_log.metadata.present?
        format_audit_json(audit_log.metadata)
      else
        para '无'
      end
    end
  end

  # Custom CSV export with selected fields
  csv do
    column :id
    column :action
    column('操作人') { |log| log.actor&.email || '系统' }
    column :target_type
    column :target_id
    column :ip
    column :request_id
    column :created_at
  end
end
