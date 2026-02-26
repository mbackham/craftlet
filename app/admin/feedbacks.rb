# frozen_string_literal: true

ActiveAdmin.register Feedback do
  menu priority: 5, label: -> { I18n.t('active_admin.feedback.menu') }
  
  # =============================
  # 权限配置
  # =============================
  permit_params :status, :priority, :admin_note, :response
  
  # =============================
  # Scopes
  # =============================
  scope :all, default: true
  scope proc { I18n.t('admin.scopes.feedback_pending') }, :pending do |scope|
    scope.where(status: 'pending')
  end
  scope proc { I18n.t('admin.scopes.feedback_reviewing') }, :reviewing do |scope|
    scope.where(status: 'reviewing')
  end
  scope proc { I18n.t('admin.scopes.feedback_resolved') }, :resolved do |scope|
    scope.where(status: 'resolved')
  end
  scope proc { I18n.t('admin.scopes.today') }, :today do |scope|
    scope.where('created_at >= ?', Time.current.beginning_of_day)
  end
  
  # =============================
  # 筛选器
  # =============================
  filter :tracking_number
  filter :feedback_type, as: :select, collection: -> { Feedback.feedback_types.keys.map { |k| [I18n.t("activerecord.attributes.feedback.feedback_types.#{k}"), k] } }
  filter :status, as: :select, collection: -> { Feedback.statuses.keys.map { |k| [I18n.t("activerecord.attributes.feedback.statuses.#{k}"), k] } }
  filter :priority, as: :select, collection: -> { Feedback.priorities.keys.map { |k| [I18n.t("activerecord.attributes.feedback.priorities.#{k}"), k] } }
  filter :submitter_email
  filter :user_id
  filter :admin_user_id
  filter :created_at
  filter :resolved_at
  
  # =============================
  # 批量操作
  # =============================
  batch_action :mark_as_reviewing, if: proc { current_admin_user.admin_can?('feedback:manage') } do |ids|
    Feedback.where(id: ids).update_all(status: 'reviewing')
    redirect_to collection_path, notice: "已标记为处理中"
  end
  
  batch_action :mark_as_resolved, if: proc { current_admin_user.admin_can?('feedback:manage') } do |ids|
    Feedback.where(id: ids).update_all(
      status: 'resolved',
      resolved_at: Time.current,
      admin_user_id: current_admin_user.id
    )
    redirect_to collection_path, notice: "已标记为已解决"
  end
  
  # =============================
  # 列表显示
  # =============================
  index do
    selectable_column
    id_column
    
    column :tracking_number, sortable: :tracking_number do |f|
      link_to f.tracking_number, admin_feedback_path(f)
    end
    
    column :feedback_type, sortable: :feedback_type do |f|
      status_tag f.feedback_type_i18n, class: feedback_type_color(f)
    end
    
    column :subject, sortable: :subject do |f|
      truncate(f.subject, length: 50)
    end
    
    column :submitter, sortable: :submitter_email do |f|
      div do
        strong f.submitter_name
      end
      div do
        f.submitter_email
      end
    end
    
    column :status, sortable: :status do |f|
      status_tag f.status_i18n, class: status_color(f.status)
    end
    
    column :priority, sortable: :priority do |f|
      status_tag f.priority_i18n, class: priority_color(f.priority)
    end
    
    column :screenshots do |f|
      f.screenshots.count if f.screenshots.attached?
    end
    
    column :created_at, sortable: :created_at
    
    actions
  end
  
  # =============================
  # 详情页
  # =============================
  show do
    attributes_table do
      row :tracking_number do |f|
        strong f.tracking_number
      end
      
      row :feedback_type do |f|
        status_tag f.feedback_type_i18n, class: feedback_type_color(f)
      end
      
      row :status do |f|
        status_tag f.status_i18n, class: status_color(f.status)
      end
      
      row :priority do |f|
        status_tag f.priority_i18n, class: priority_color(f.priority)
      end
      
      row :subject
      
      row :content do |f|
        simple_format f.content
      end
      
      row :screenshots do |f|
        if f.screenshots.attached?
          div class: 'screenshots-gallery' do
            f.screenshots.each do |img|
              span do
                link_to rails_blob_path(img, disposition: 'attachment'), target: '_blank' do
                  image_tag rails_representation_url(img.variant(:thumb)), 
                           style: 'margin: 5px; border: 1px solid #ddd; border-radius: 4px;'
                end
              end
            end
          end
        else
          span '无附件'
        end
      end
      
      row :submitter_info do |f|
        panel "" do
          attributes_table_for f do
            row('姓名') { f.submitter_name }
            row('邮箱') { mail_to f.submitter_email }
            row('电话') { sensitive_field(f.submitter_phone, mask_method: :mask_phone, admin_user: current_admin_user) }
            row('关联用户') do
              if f.user_id.present?
                link_to "#{f.user_type} ##{f.user_id}", [:admin, f.user] rescue f.user_type
              else
                '访客'
              end
            end
          end
        end
      end
      
      row :environment_info do |f|
        panel "" do
          attributes_table_for f do
            row('页面URL') { link_to f.page_url, f.page_url, target: '_blank' if f.page_url.present? }
            row('IP地址') { f.ip_address }
            row('User Agent') { truncate(f.user_agent, length: 100) if f.user_agent.present? }
          end
        end
      end
      
      row :created_at
      row :updated_at
    end
    
    panel "处理记录" do
      attributes_table_for feedback do
        row :admin_user do |f|
          link_to f.admin_user.email, admin_admin_user_path(f.admin_user) if f.admin_user
        end
        row :admin_note do |f|
          simple_format f.admin_note if f.admin_note.present?
        end
        row :response do |f|
          simple_format f.response if f.response.present?
        end
        row :resolved_at
      end
    end
    
    active_admin_comments
  end
  
  # =============================
  # 编辑表单
  # =============================
  form do |f|
    f.semantic_errors
    
    f.inputs "状态管理" do
      f.input :status, as: :select, 
              collection: Feedback.statuses.keys.map { |k| [I18n.t("activerecord.attributes.feedback.statuses.#{k}"), k] },
              include_blank: false
      f.input :priority, as: :select,
              collection: Feedback.priorities.keys.map { |k| [I18n.t("activerecord.attributes.feedback.priorities.#{k}"), k] },
              include_blank: false
    end
    
    f.inputs "处理信息" do
      f.input :admin_note, as: :text, 
              input_html: { rows: 5 },
              hint: "内部备注，用户不可见"
      f.input :response, as: :text,
              input_html: { rows: 8 },
              hint: "填写后将通过邮件发送给用户"
    end
    
    f.actions
  end
  
  # =============================
  # 回调：回复后发送邮件
  # =============================
  after_update do |feedback|
    if feedback.response.present? && feedback.saved_change_to_response?
      feedback.update(admin_user_id: current_admin_user.id)
      FeedbackMailer.response_notification(feedback).deliver_later
    end
  end
  
  # =============================
  # 辅助方法
  # =============================
  controller do
    helper SensitiveFieldHelper

    def feedback_type_color(feedback)
      case feedback.feedback_type
      when 'bug_report' then 'error'
      when 'feature_request' then 'ok'
      when 'complaint' then 'warning'
      else 'default'
      end
    end
    
    def status_color(status)
      case status
      when 'pending' then 'warning'
      when 'reviewing' then 'default'
      when 'resolved' then 'ok'
      when 'closed' then ''
      end
    end
    
    def priority_color(priority)
      case priority
      when 'urgent' then 'error'
      when 'high' then 'warning'
      when 'medium' then 'default'
      when 'low' then ''
      end
    end
    
    helper_method :feedback_type_color, :status_color, :priority_color
  end
end
