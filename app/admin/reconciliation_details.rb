ActiveAdmin.register ReconciliationDetail do
  menu parent: I18n.t('admin.menu.finance', default: '财务管理'), label: -> { I18n.t('admin.labels.reconciliation_details', default: '对账差异处理') }, priority: 3

  actions :index, :show

  filter :reconciliation_batch
  filter :transaction_no
  filter :order_no
  filter :reconciliation_type
  filter :match_status
  filter :process_status

  index do
    selectable_column
    id_column
    column :transaction_no
    column :order_no
    column :reconciliation_type do |detail|
      status_tag detail.reconciliation_type, class: detail.reconciliation_type == 'payment' ? 'ok' : 'warn'
    end
    column :statement_amount
    column :system_amount
    column :match_status do |detail|
      status_tag detail.match_status, class: detail.match_status == 'matched' ? 'ok' : 'error'
    end
    column :process_status do |detail|
      status_tag detail.process_status, class: case detail.process_status
                                               when 'pending' then 'error'
                                               when 'claimed' then 'warn'
                                               when 'adjusted', 'ignored' then 'ok'
                                               end
    end
    column :handler_admin do |detail|
      detail.handler_admin&.email
    end
    
    actions defaults: true do |detail|
      if detail.process_status == 'pending'
        item I18n.t('admin.actions.claim', default: '认领'), claim_admin_reconciliation_detail_path(detail), method: :put, class: "member_link"
      end
      if detail.process_status == 'claimed' && detail.handler_admin_id == current_admin_user.id
        item I18n.t('admin.actions.adjust', default: '调账平账'), adjust_admin_reconciliation_detail_path(detail), method: :get, class: "member_link"
        item I18n.t('admin.actions.ignore', default: '忽略'), ignore_admin_reconciliation_detail_path(detail), method: :put, class: "member_link"
      end
    end
  end

  # --- Custom Actions ---
  member_action :claim, method: :put do
    resource.update!(process_status: 'claimed', handler_admin_id: current_admin_user.id)
    redirect_to admin_reconciliation_details_path, notice: I18n.t('admin.notices.claimed', default: '已成功认领记录')
  end

  member_action :adjust, method: :get do
    @page_title = I18n.t('admin.reconciliation.adjust_title', default: '处理对账差异')
    render 'admin/reconciliation_details/adjust'
  end

  member_action :do_adjust, method: :put do
    reason = params[:adjustment_reason]
    if reason.present?
      resource.update!(process_status: 'adjusted', adjustment_reason: reason)
      redirect_to admin_reconciliation_details_path, notice: I18n.t('admin.notices.adjusted', default: '已调账平账')
    else
      redirect_to adjust_admin_reconciliation_detail_path(resource), alert: I18n.t('admin.alerts.empty_reason', default: '调账原因不能为空')
    end
  end

  member_action :ignore, method: :put do
    resource.update!(process_status: 'ignored')
    redirect_to admin_reconciliation_details_path, notice: I18n.t('admin.notices.ignored', default: '已忽略该差异记录')
  end
end
