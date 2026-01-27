# frozen_string_literal: true

ActiveAdmin.register AuditLog do
  menu parent: 'RBAC管理', priority: 4

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
    column :action do |log|
      action_badge(log.action)
    end
    column '操作人' do |log|
      if log.actor
        link_to log.actor.email, admin_user_path(log.actor)
      else
        content_tag(:span, '系统', class: 'system')
      end
    end
    column '目标' do |log|
      audit_target_link(log)
    end
    column :ip
    column :created_at
    actions
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
      row :id
      row :action do |log|
        action_badge(log.action)
      end
      row '操作人' do |log|
        if log.actor
          link_to log.actor.email, admin_user_path(log.actor)
        else
          content_tag(:span, '系统', class: 'system')
        end
      end
      row :target_type
      row :target_id
      row '目标' do |log|
        audit_target_link(log)
      end
      row :request_id
      row :ip
      row :user_agent
      row :created_at
      row :updated_at
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
