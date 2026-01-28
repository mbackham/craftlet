# frozen_string_literal: true

ActiveAdmin.register MerchantProfile do
  menu parent: '商家管理', priority: 1, label: '商家审核'

  permit_params :user_id, :shop_name, :status, :address_province, :address_city, 
                :address_district, :address_detail, :license_file_key,
                :idcard_front_key, :idcard_back_key, :bank_name, :bank_branch

  controller do
    include Auditable
    helper AuditHelper

    after_action :audit_create, only: [:create]
    after_action :audit_update, only: [:update]
    after_action :audit_destroy, only: [:destroy]

    # Custom audit logging for approval actions
    def log_approval_action(action_name, merchant_profile, metadata = {})
      AuditService.log!(
        action: action_name,
        actor: current_admin_user,
        target: merchant_profile,
        before: { status: merchant_profile.status_before_last_save },
        after: { status: merchant_profile.status },
        metadata: metadata,
        request: request
      )
    end
  end

  # === Scopes ===
  scope :all, default: true
  scope('待审核') { |scope| scope.submitted }
  scope('已通过') { |scope| scope.approved }
  scope('已拒绝') { |scope| scope.rejected }
  scope('已停用') { |scope| scope.suspended }
  scope('待提交') { |scope| scope.pending }

  # === Filters ===
  filter :shop_name
  filter :status, as: :select, collection: MerchantProfile::STATUSES.map { |s| 
    [I18n.t("merchant_statuses.#{s}", default: s.humanize), s] 
  }
  filter :address_province
  filter :address_city
  filter :user_email, as: :string, label: '用户邮箱'
  filter :created_at
  filter :approved_at
  filter :rejected_at

  # === Index ===
  index do
    selectable_column
    id_column
    column '店铺名称', :shop_name
    column '关联用户' do |mp|
      link_to mp.user.email, admin_user_path(mp.user)
    end
    column '状态' do |mp|
      status_color = case mp.status
                     when 'approved' then 'yes'
                     when 'rejected' then 'error'
                     when 'submitted' then 'warning'
                     when 'suspended' then 'no'
                     else nil
                     end
      status_tag I18n.t("merchant_statuses.#{mp.status}", default: mp.status.humanize), 
                 class: status_color
    end
    column '省/市', sortable: :address_province do |mp|
      "#{mp.address_province} #{mp.address_city}"
    end
    column '提交时间', :created_at
    column '审批时间' do |mp|
      mp.approved_at || mp.rejected_at
    end
    actions name: '操作'
  end

  # === Show ===
  show title: proc { |mp| "商家资料 - #{mp.shop_name}" } do
    columns do
      column do
        panel '基本信息' do
          attributes_table_for merchant_profile do
            row('ID') { |mp| mp.id }
            row('店铺名称') { |mp| mp.shop_name }
            row('状态') do |mp|
              status_color = case mp.status
                             when 'approved' then 'yes'
                             when 'rejected' then 'error'
                             when 'submitted' then 'warning'
                             when 'suspended' then 'no'
                             else nil
                             end
              status_tag I18n.t("merchant_statuses.#{mp.status}", default: mp.status.humanize), 
                         class: status_color
            end
            row('关联用户') { |mp| link_to mp.user.email, admin_user_path(mp.user) }
            row('创建时间') { |mp| l(mp.created_at, format: :long) if mp.created_at }
            row('更新时间') { |mp| l(mp.updated_at, format: :long) if mp.updated_at }
          end
        end

        panel '地址信息' do
          attributes_table_for merchant_profile do
            row('省份') { |mp| mp.address_province }
            row('城市') { |mp| mp.address_city }
            row('区县') { |mp| mp.address_district }
            row('详细地址') { |mp| mp.address_detail }
            row('完整地址') { |mp| mp.full_address }
          end
        end
      end

      column do
        panel 'KYC 资料' do
          attributes_table_for merchant_profile do
            row('营业执照') do |mp|
              if mp.license_file_key.present?
                link_to '查看/下载', mp.license_file_key, target: '_blank'
              else
                span '未上传', class: 'empty'
              end
            end
            row('身份证正面') do |mp|
              if mp.idcard_front_key.present?
                link_to '查看/下载', mp.idcard_front_key, target: '_blank'
              else
                span '未上传', class: 'empty'
              end
            end
            row('身份证反面') do |mp|
              if mp.idcard_back_key.present?
                link_to '查看/下载', mp.idcard_back_key, target: '_blank'
              else
                span '未上传', class: 'empty'
              end
            end
          end
        end

        panel '银行账户信息' do
          attributes_table_for merchant_profile do
            row('开户银行') { |mp| mp.bank_name }
            row('开户支行') { |mp| mp.bank_branch }
            row('银行账号') { |mp| mp.masked_bank_account_no || '未填写' }
            row('保证金金额') { |mp| number_to_currency(mp.deposit_amount, unit: '¥') if mp.deposit_amount }
          end
        end
      end
    end

    # Approval Panel
    if merchant_profile.rejected?
      panel '拒绝信息', class: 'rejection-panel' do
        attributes_table_for merchant_profile do
          row('拒绝原因') { |mp| mp.reject_reason }
          row('拒绝时间') { |mp| l(mp.rejected_at, format: :long) if mp.rejected_at }
          row('操作人') do |mp|
            if mp.rejected_by_admin
              link_to mp.rejected_by_admin.email, admin_admin_user_path(mp.rejected_by_admin)
            else
              '未知'
            end
          end
        end
      end
    end

    if merchant_profile.approved?
      panel '审批信息', class: 'approval-panel' do
        attributes_table_for merchant_profile do
          row('审批时间') { |mp| l(mp.approved_at, format: :long) if mp.approved_at }
          row('操作人') do |mp|
            if mp.approved_by_admin
              link_to mp.approved_by_admin.email, admin_admin_user_path(mp.approved_by_admin)
            else
              '未知'
            end
          end
        end
      end
    end

    panel '审批历史' do
      if merchant_profile.review_logs.any?
        table_for merchant_profile.review_logs.recent do
          column('操作') do |log|
            action_color = case log.action
                           when 'approve' then 'yes'
                           when 'reject' then 'error'
                           when 'submit' then 'warning'
                           when 'suspend' then 'no'
                           else nil
                           end
            status_tag I18n.t("merchant_review_actions.#{log.action}", default: log.action.humanize),
                       class: action_color
          end
          column('操作人') { |log| log.operator_display_name }
          column('备注') { |log| log.note }
          column('时间') { |log| l(log.created_at, format: :long) if log.created_at }
        end
      else
        para '暂无审批记录'
      end
    end

    panel '最近审计日志' do
      audit_logs = AuditLog.where(target_type: 'MerchantProfile', target_id: merchant_profile.id)
                           .order(created_at: :desc).limit(10)
      if audit_logs.any?
        table_for audit_logs do
          column('操作') do |log|
            status_tag log.action, class: log.action.to_s.downcase
          end
          column('操作人') do |log|
            log.actor&.email || '系统'
          end
          column('IP地址') { |log| log.ip }
          column('时间') { |log| l(log.created_at, format: :long) if log.created_at }
          column('详情') do |log|
            link_to '查看', admin_audit_log_path(log)
          end
        end
      else
        para '暂无审计日志'
      end
    end
  end

  # === Form ===
  form do |f|
    # 获取没有商家资料的用户，或编辑时包含当前用户
    available_users = if f.object.new_record?
      User.left_joins(:merchant_profile).where(merchant_profiles: { id: nil })
    else
      User.left_joins(:merchant_profile).where('merchant_profiles.id IS NULL OR users.id = ?', f.object.user_id)
    end

    f.inputs '关联用户' do
      f.input :user_id, as: :select, 
              collection: available_users.order(:email).map { |u| ["#{u.email} (#{u.nickname || 'N/A'})", u.id] },
              include_blank: '请选择用户',
              hint: '只显示尚未创建商家资料的用户'
    end

    f.inputs '基本信息' do
      f.input :shop_name
      f.input :status, as: :select, collection: MerchantProfile::STATUSES.map { |s| 
        [I18n.t("merchant_statuses.#{s}", default: s.humanize), s] 
      }, include_blank: false
    end

    f.inputs '地址信息' do
      f.input :address_province
      f.input :address_city
      f.input :address_district
      f.input :address_detail
    end

    f.inputs 'KYC 文件 (OSS Key)' do
      f.input :license_file_key, hint: '营业执照 OSS Key'
      f.input :idcard_front_key, hint: '身份证正面 OSS Key'
      f.input :idcard_back_key, hint: '身份证反面 OSS Key'
    end

    f.inputs '银行信息' do
      f.input :bank_name
      f.input :bank_branch
    end

    f.actions
  end

  # === Member Actions ===
  member_action :approve, method: :put do
    merchant_profile = MerchantProfile.find(params[:id])
    
    unless merchant_profile.can_approve?
      redirect_to admin_merchant_profile_path(merchant_profile), 
                  alert: '当前状态不允许审批操作'
      return
    end

    ActiveRecord::Base.transaction do
      old_status = merchant_profile.status
      
      admin_uuid = MerchantProfile.format_admin_id_as_uuid(current_admin_user.id)
      
      merchant_profile.update!(
        status: 'approved',
        approved_at: Time.current,
        approved_by_admin_id: admin_uuid
      )

      merchant_profile.review_logs.create!(
        action: 'approve',
        operator_admin_id: admin_uuid,
        note: '审核通过'
      )

      AuditService.log!(
        action: 'approve',
        actor: current_admin_user,
        target: merchant_profile,
        before: { status: old_status },
        after: { status: 'approved' },
        metadata: { action_type: 'merchant_approval' },
        request: request
      )
    end

    redirect_to admin_merchant_profile_path(merchant_profile), notice: '商家审核已通过！'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_merchant_profile_path(merchant_profile), alert: "操作失败: #{e.message}"
  end

  member_action :reject, method: [:get, :put] do
    merchant_profile = MerchantProfile.find(params[:id])
    
    unless merchant_profile.can_reject?
      redirect_to admin_merchant_profile_path(merchant_profile), 
                  alert: '当前状态不允许拒绝操作'
      return
    end

    # GET: 显示拒绝原因输入表单
    if request.get?
      render inline: <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>拒绝商家申请</title>
          <style>
            body { font-family: sans-serif; padding: 40px; background: #f5f5f5; }
            .container { max-width: 500px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            h2 { margin-top: 0; color: #333; }
            label { display: block; margin-bottom: 8px; font-weight: bold; }
            textarea { width: 100%; height: 120px; padding: 10px; border: 1px solid #ccc; border-radius: 4px; font-size: 14px; }
            .buttons { margin-top: 20px; }
            button { padding: 10px 20px; font-size: 14px; border-radius: 4px; cursor: pointer; margin-right: 10px; }
            .submit { background: #e74c3c; color: white; border: none; }
            .cancel { background: #95a5a6; color: white; border: none; }
          </style>
        </head>
        <body>
          <div class="container">
            <h2>拒绝商家申请</h2>
            <p>商家: <strong>#{merchant_profile.shop_name}</strong></p>
            <form method="POST" action="#{reject_admin_merchant_profile_path(merchant_profile)}">
              <input type="hidden" name="_method" value="put">
              <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">
              <label for="reject_reason">请输入拒绝原因：</label>
              <textarea name="reject_reason" id="reject_reason" required placeholder="请说明拒绝原因..."></textarea>
              <div class="buttons">
                <button type="submit" class="submit">确认拒绝</button>
                <a href="#{admin_merchant_profile_path(merchant_profile)}"><button type="button" class="cancel">取消</button></a>
              </div>
            </form>
          </div>
        </body>
        </html>
      HTML
      return
    end

    # PUT: 处理拒绝操作
    reject_reason = params[:reject_reason].presence || params[:reason].presence
    
    if reject_reason.blank?
      redirect_to admin_merchant_profile_path(merchant_profile), 
                  alert: '请填写拒绝原因'
      return
    end

    ActiveRecord::Base.transaction do
      old_status = merchant_profile.status
      admin_uuid = MerchantProfile.format_admin_id_as_uuid(current_admin_user.id)
      
      merchant_profile.update!(
        status: 'rejected',
        rejected_at: Time.current,
        rejected_by_admin_id: admin_uuid,
        reject_reason: reject_reason
      )

      merchant_profile.review_logs.create!(
        action: 'reject',
        operator_admin_id: admin_uuid,
        note: reject_reason
      )

      AuditService.log!(
        action: 'reject',
        actor: current_admin_user,
        target: merchant_profile,
        before: { status: old_status },
        after: { status: 'rejected', reject_reason: reject_reason },
        metadata: { action_type: 'merchant_rejection', reason: reject_reason },
        request: request
      )
    end

    redirect_to admin_merchant_profile_path(merchant_profile), notice: '商家申请已拒绝'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_merchant_profile_path(merchant_profile), alert: "操作失败: #{e.message}"
  end

  member_action :suspend, method: :put do
    merchant_profile = MerchantProfile.find(params[:id])
    suspend_reason = params[:reason].presence || '运营封禁'
    
    unless merchant_profile.approved?
      redirect_to admin_merchant_profile_path(merchant_profile), 
                  alert: '只能停用已通过审核的商家'
      return
    end

    ActiveRecord::Base.transaction do
      old_status = merchant_profile.status
      
      merchant_profile.update!(status: 'suspended')

      admin_uuid = MerchantProfile.format_admin_id_as_uuid(current_admin_user.id)
      
      merchant_profile.review_logs.create!(
        action: 'suspend',
        operator_admin_id: admin_uuid,
        note: suspend_reason
      )

      AuditService.log!(
        action: 'suspend',
        actor: current_admin_user,
        target: merchant_profile,
        before: { status: old_status },
        after: { status: 'suspended' },
        metadata: { action_type: 'merchant_suspension', reason: suspend_reason },
        request: request
      )
    end

    redirect_to admin_merchant_profile_path(merchant_profile), notice: '商家已停用'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_merchant_profile_path(merchant_profile), alert: "操作失败: #{e.message}"
  end

  member_action :unsuspend, method: :put do
    merchant_profile = MerchantProfile.find(params[:id])
    
    unless merchant_profile.suspended?
      redirect_to admin_merchant_profile_path(merchant_profile), 
                  alert: '只能解除已停用的商家'
      return
    end

    ActiveRecord::Base.transaction do
      merchant_profile.update!(status: 'approved')

      admin_uuid = MerchantProfile.format_admin_id_as_uuid(current_admin_user.id)
      
      merchant_profile.review_logs.create!(
        action: 'unsuspend',
        operator_admin_id: admin_uuid,
        note: '解除停用'
      )

      AuditService.log!(
        action: 'unsuspend',
        actor: current_admin_user,
        target: merchant_profile,
        before: { status: 'suspended' },
        after: { status: 'approved' },
        metadata: { action_type: 'merchant_unsuspension' },
        request: request
      )
    end

    redirect_to admin_merchant_profile_path(merchant_profile), notice: '商家已恢复'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_merchant_profile_path(merchant_profile), alert: "操作失败: #{e.message}"
  end

  # === Action Items ===
  action_item :approve, only: :show, if: proc { merchant_profile.can_approve? } do
    link_to '通过审核', approve_admin_merchant_profile_path(merchant_profile), 
            method: :put,
            data: { confirm: '确认通过该商家的审核申请？' },
            class: 'action-item-button'
  end

  action_item :reject, only: :show, if: proc { merchant_profile.can_reject? } do
    link_to '拒绝申请', reject_admin_merchant_profile_path(merchant_profile),
            class: 'action-item-button'
  end

  action_item :suspend, only: :show, if: proc { merchant_profile.approved? } do
    link_to '停用商家', suspend_admin_merchant_profile_path(merchant_profile),
            method: :put,
            data: { confirm: '确认停用该商家？' },
            class: 'action-item-button'
  end

  action_item :unsuspend, only: :show, if: proc { merchant_profile.suspended? } do
    link_to '恢复商家', unsuspend_admin_merchant_profile_path(merchant_profile),
            method: :put,
            data: { confirm: '确认恢复该商家？' },
            class: 'action-item-button'
  end

  # === Batch Actions ===
  batch_action :approve, if: proc { current_admin_user.admin_can?('merchant:approve') } do |ids|
    batch_action_collection.find(ids).each do |merchant_profile|
      next unless merchant_profile.can_approve?
      
      admin_uuid = MerchantProfile.format_admin_id_as_uuid(current_admin_user.id)
      
      merchant_profile.update!(
        status: 'approved',
        approved_at: Time.current,
        approved_by_admin_id: admin_uuid
      )
      
      merchant_profile.review_logs.create!(
        action: 'approve',
        operator_admin_id: admin_uuid,
        note: '批量审核通过'
      )
    end
    redirect_to collection_path, notice: "已批量通过 #{ids.size} 个商家审核"
  end

  batch_action :reject, form: { reason: :text }, 
               if: proc { current_admin_user.admin_can?('merchant:approve') } do |ids, inputs|
    reason = inputs[:reason].presence || '批量拒绝'
    
    batch_action_collection.find(ids).each do |merchant_profile|
      next unless merchant_profile.can_reject?
      
      admin_uuid = MerchantProfile.format_admin_id_as_uuid(current_admin_user.id)
      
      merchant_profile.update!(
        status: 'rejected',
        rejected_at: Time.current,
        rejected_by_admin_id: admin_uuid,
        reject_reason: reason
      )
      
      merchant_profile.review_logs.create!(
        action: 'reject',
        operator_admin_id: admin_uuid,
        note: reason
      )
    end
    redirect_to collection_path, notice: "已批量拒绝 #{ids.size} 个商家申请"
  end

  # === CSV Export ===
  csv do
    column :id
    column :shop_name
    column('用户邮箱') { |mp| mp.user.email }
    column('状态') { |mp| I18n.t("merchant_statuses.#{mp.status}", default: mp.status) }
    column :address_province
    column :address_city
    column :address_district
    column :address_detail
    column :bank_name
    column :bank_branch
    column :created_at
    column :approved_at
    column :rejected_at
    column :reject_reason
  end
end
