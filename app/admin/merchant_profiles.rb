# frozen_string_literal: true

ActiveAdmin.register MerchantProfile do
  menu parent: proc { I18n.t('admin.menu.merchants') }, priority: 1, label: proc { I18n.t('admin.labels.merchant_profiles') }

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
  scope :submitted, label: proc { I18n.t('admin.scopes.pending_review') }
  scope :approved, label: proc { I18n.t('admin.scopes.approved') }
  scope :rejected, label: proc { I18n.t('admin.scopes.rejected') }
  scope :suspended, label: proc { I18n.t('admin.scopes.suspended') }
  scope :pending, label: proc { I18n.t('admin.scopes.pending_submit') }

  # === Filters ===
  filter :shop_name
  filter :status, as: :select, collection: MerchantProfile::STATUSES.map { |s| 
    [I18n.t("merchant_statuses.#{s}", default: s.humanize), s] 
  }
  filter :address_province
  filter :address_city
  filter :user_email, as: :string, label: proc { User.human_attribute_name(:email) }
  filter :created_at
  filter :approved_at
  filter :rejected_at

  # === Index ===
  index do
    selectable_column
    id_column
    column I18n.t('admin.columns.shop_name'), :shop_name
    column I18n.t('admin.columns.related_user') do |mp|
      link_to mp.user.email, admin_user_path(mp.user)
    end
    column I18n.t('admin.columns.status') do |mp|
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
    column I18n.t('admin.columns.province_city'), sortable: :address_province do |mp|
      "#{mp.address_province} #{mp.address_city}"
    end
    column I18n.t('admin.columns.submit_time'), :created_at
    column I18n.t('admin.columns.approval_time') do |mp|
      mp.approved_at || mp.rejected_at
    end
    actions name: I18n.t('admin.columns.actions')
  end

  # === Show ===
  show title: proc { |mp| I18n.t('admin.titles.merchant_profile', name: mp.shop_name) } do
    columns do
      column do
        panel I18n.t('admin.panels.basic_info') do
          attributes_table_for merchant_profile do
            row('ID') { |mp| mp.id }
            row(I18n.t('admin.columns.shop_name')) { |mp| mp.shop_name }
            row(I18n.t('admin.columns.status')) do |mp|
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
            row(I18n.t('admin.columns.related_user')) { |mp| link_to mp.user.email, admin_user_path(mp.user) }
            row(:created_at) { |mp| l(mp.created_at, format: :long) if mp.created_at }
            row(:updated_at) { |mp| l(mp.updated_at, format: :long) if mp.updated_at }
          end
        end

        panel I18n.t('admin.panels.address_info') do
          attributes_table_for merchant_profile do
            row(:address_province) { |mp| mp.address_province }
            row(:address_city) { |mp| mp.address_city }
            row(:address_district) { |mp| mp.address_district }
            row(:address_detail) { |mp| mp.address_detail }
            row(:full_address) { |mp| mp.full_address }
          end
        end
      end

      column do
        panel I18n.t('admin.panels.kyc_info') do
          attributes_table_for merchant_profile do
            row(:license_file_key) do |mp|
              if mp.license_file_key.present?
                link_to I18n.t('admin.actions.view'), mp.license_file_key, target: '_blank'
              else
                span I18n.t('admin.messages.not_uploaded'), class: 'empty'
              end
            end
            row(:idcard_front_key) do |mp|
              if mp.idcard_front_key.present?
                link_to I18n.t('admin.actions.view'), mp.idcard_front_key, target: '_blank'
              else
                span I18n.t('admin.messages.not_uploaded'), class: 'empty'
              end
            end
            row(:idcard_back_key) do |mp|
              if mp.idcard_back_key.present?
                link_to I18n.t('admin.actions.view'), mp.idcard_back_key, target: '_blank'
              else
                span I18n.t('admin.messages.not_uploaded'), class: 'empty'
              end
            end
          end
        end

        panel I18n.t('admin.panels.bank_info') do
          attributes_table_for merchant_profile do
            row(:bank_name) { |mp| mp.bank_name }
            row(:bank_branch) { |mp| mp.bank_branch }
            row(:bank_account_no) { |mp| mp.masked_bank_account_no || I18n.t('admin.messages.not_filled') }
            row(:deposit_amount) { |mp| number_to_currency(mp.deposit_amount, unit: '¥') if mp.deposit_amount }
          end
        end
      end
    end

    # Approval Panel
    if merchant_profile.rejected?
      panel I18n.t('admin.panels.rejection_info'), class: 'rejection-panel' do
        attributes_table_for merchant_profile do
          row(:reject_reason) { |mp| mp.reject_reason }
          row(:rejected_at) { |mp| l(mp.rejected_at, format: :long) if mp.rejected_at }
          row(I18n.t('admin.columns.operator')) do |mp|
            if mp.rejected_by_admin
              link_to mp.rejected_by_admin.email, admin_admin_user_path(mp.rejected_by_admin)
            else
              I18n.t('admin.messages.unknown')
            end
          end
        end
      end
    end

    if merchant_profile.approved?
      panel I18n.t('admin.panels.approval_info'), class: 'approval-panel' do
        attributes_table_for merchant_profile do
          row(:approved_at) { |mp| l(mp.approved_at, format: :long) if mp.approved_at }
          row(I18n.t('admin.columns.operator')) do |mp|
            if mp.approved_by_admin
              link_to mp.approved_by_admin.email, admin_admin_user_path(mp.approved_by_admin)
            else
              I18n.t('admin.messages.unknown')
            end
          end
        end
      end
    end

    panel I18n.t('admin.panels.review_history') do
      if merchant_profile.review_logs.any?
        table_for merchant_profile.review_logs.recent do
          column(I18n.t('admin.columns.status')) do |log|
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
          column(I18n.t('admin.columns.operator')) { |log| log.operator_display_name }
          column(:note) { |log| log.note }
          column(:created_at) { |log| l(log.created_at, format: :long) if log.created_at }
        end
      else
        para I18n.t('admin.messages.no_review_history')
      end
    end

    panel I18n.t('admin.panels.recent_audit_logs') do
      audit_logs = AuditLog.where(target_type: 'MerchantProfile', target_id: merchant_profile.id)
                           .order(created_at: :desc).limit(10)
      if audit_logs.any?
        table_for audit_logs do
          column(I18n.t('admin.columns.status')) do |log|
            status_tag log.action, class: log.action.to_s.downcase
          end
          column(I18n.t('admin.columns.operator')) do |log|
            log.actor&.email || I18n.t('admin.messages.system')
          end
          column(I18n.t('admin.columns.ip_address')) { |log| log.ip }
          column(:created_at) { |log| l(log.created_at, format: :long) if log.created_at }
          column(I18n.t('admin.actions.view')) do |log|
            link_to I18n.t('admin.actions.view'), admin_audit_log_path(log)
          end
        end
      else
        para I18n.t('admin.messages.no_audit_logs')
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

    f.inputs I18n.t('admin.panels.related_user') do
      f.input :user_id, as: :select, 
              collection: available_users.order(:email).map { |u| ["#{u.email} (#{u.nickname || 'N/A'})", u.id] },
              include_blank: I18n.t('admin.forms.select_user'),
              hint: I18n.t('admin.forms.only_users_without_merchant')
    end

    f.inputs I18n.t('admin.panels.basic_info') do
      f.input :shop_name
      f.input :status, as: :select, collection: MerchantProfile::STATUSES.map { |s| 
        [I18n.t("merchant_statuses.#{s}", default: s.humanize), s] 
      }, include_blank: false
    end

    f.inputs I18n.t('admin.panels.address_info') do
      f.input :address_province
      f.input :address_city
      f.input :address_district
      f.input :address_detail
    end

    f.inputs I18n.t('admin.panels.kyc_info') do
      f.input :license_file_key, hint: I18n.t('admin.forms.license_hint')
      f.input :idcard_front_key, hint: I18n.t('admin.forms.idcard_front_hint')
      f.input :idcard_back_key, hint: I18n.t('admin.forms.idcard_back_hint')
    end

    f.inputs I18n.t('admin.panels.bank_info') do
      f.input :bank_name
      f.input :bank_branch
    end

    f.actions
  end

  # === Member Actions ===
  member_action :approve, method: :put do
    merchant_profile = MerchantProfile.find(params[:id])
    service = Merchants::ApproveService.new(
      merchant_profile: merchant_profile,
      admin_user: current_admin_user,
      request: request
    ).call

    if service.success?
      redirect_to admin_merchant_profile_path(merchant_profile), notice: I18n.t('admin.notices.merchant_approved')
    else
      redirect_to admin_merchant_profile_path(merchant_profile), alert: I18n.t('admin.notices.operation_failed', error: service.error)
    end
  end

  member_action :reject, method: [:get, :put] do
    merchant_profile = MerchantProfile.find(params[:id])
    
    unless merchant_profile.can_reject?
      redirect_to admin_merchant_profile_path(merchant_profile), 
                  alert: I18n.t('admin.alerts.status_not_allow_reject')
      return
    end

    # GET: 显示拒绝原因输入表单
    if request.get?
      render inline: <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>#{I18n.t('admin.titles.reject_merchant')}</title>
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
            <h2>#{I18n.t('admin.rejection_form.title')}</h2>
            <p>#{I18n.t('admin.rejection_form.merchant_label')}: <strong>#{merchant_profile.shop_name}</strong></p>
            <form method="POST" action="#{reject_admin_merchant_profile_path(merchant_profile)}">
              <input type="hidden" name="_method" value="put">
              <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">
              <label for="reject_reason">#{I18n.t('admin.rejection_form.reason_label')}</label>
              <textarea name="reject_reason" id="reject_reason" required placeholder="#{I18n.t('admin.rejection_form.reason_placeholder')}"></textarea>
              <div class="buttons">
                <button type="submit" class="submit">#{I18n.t('admin.rejection_form.confirm_btn')}</button>
                <a href="#{admin_merchant_profile_path(merchant_profile)}"><button type="button" class="cancel">#{I18n.t('admin.rejection_form.cancel_btn')}</button></a>
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
    
    service = Merchants::RejectService.new(
      merchant_profile: merchant_profile,
      admin_user: current_admin_user,
      reason: reject_reason,
      request: request
    ).call

    if service.success?
      redirect_to admin_merchant_profile_path(merchant_profile), notice: I18n.t('admin.notices.merchant_rejected')
    else
      redirect_to admin_merchant_profile_path(merchant_profile), alert: I18n.t('admin.notices.operation_failed', error: service.error)
    end
  end

  member_action :suspend, method: :put do
    merchant_profile = MerchantProfile.find(params[:id])
    suspend_reason = params[:reason].presence || 'Admin suspension'
    
    unless merchant_profile.approved?
      redirect_to admin_merchant_profile_path(merchant_profile), 
                  alert: I18n.t('admin.alerts.only_suspend_approved')
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

    redirect_to admin_merchant_profile_path(merchant_profile), notice: I18n.t('admin.notices.merchant_suspended')
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_merchant_profile_path(merchant_profile), alert: I18n.t('admin.notices.operation_failed', error: e.message)
  end

  member_action :unsuspend, method: :put do
    merchant_profile = MerchantProfile.find(params[:id])
    
    unless merchant_profile.suspended?
      redirect_to admin_merchant_profile_path(merchant_profile), 
                  alert: I18n.t('admin.alerts.only_resume_suspended')
      return
    end

    ActiveRecord::Base.transaction do
      merchant_profile.update!(status: 'approved')

      admin_uuid = MerchantProfile.format_admin_id_as_uuid(current_admin_user.id)
      
      merchant_profile.review_logs.create!(
        action: 'unsuspend',
        operator_admin_id: admin_uuid,
        note: 'Resume'
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

    redirect_to admin_merchant_profile_path(merchant_profile), notice: I18n.t('admin.notices.merchant_resumed')
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_merchant_profile_path(merchant_profile), alert: I18n.t('admin.notices.operation_failed', error: e.message)
  end

  # === Action Items ===
  action_item :approve, only: :show, if: proc { merchant_profile.can_approve? } do
    link_to I18n.t('admin.actions.approve'), approve_admin_merchant_profile_path(merchant_profile), 
            method: :put,
            data: { confirm: I18n.t('admin.confirmations.approve_merchant') },
            class: 'action-item-button'
  end

  action_item :reject, only: :show, if: proc { merchant_profile.can_reject? } do
    link_to I18n.t('admin.actions.reject'), reject_admin_merchant_profile_path(merchant_profile),
            class: 'action-item-button'
  end

  action_item :suspend, only: :show, if: proc { merchant_profile.approved? } do
    link_to I18n.t('admin.actions.suspend'), suspend_admin_merchant_profile_path(merchant_profile),
            method: :put,
            data: { confirm: I18n.t('admin.confirmations.suspend_merchant') },
            class: 'action-item-button'
  end

  action_item :unsuspend, only: :show, if: proc { merchant_profile.suspended? } do
    link_to I18n.t('admin.actions.resume'), unsuspend_admin_merchant_profile_path(merchant_profile),
            method: :put,
            data: { confirm: I18n.t('admin.confirmations.resume_merchant') },
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
        note: 'Batch approval'
      )
    end
    redirect_to collection_path, notice: "#{I18n.t('admin.messages.batch_approved')} #{ids.size}"
  end

  batch_action :reject, form: { reason: :text }, 
               if: proc { current_admin_user.admin_can?('merchant:approve') } do |ids, inputs|
    reason = inputs[:reason].presence || 'Batch rejection'
    
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
    redirect_to collection_path, notice: "#{I18n.t('admin.messages.batch_rejected')} #{ids.size}"
  end

  # === CSV Export ===
  csv do
    column :id
    column :shop_name
    column(User.human_attribute_name(:email)) { |mp| mp.user.email }
    column(I18n.t('admin.columns.status')) { |mp| I18n.t("merchant_statuses.#{mp.status}", default: mp.status) }
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
