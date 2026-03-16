ActiveAdmin.register BankStatement do
  menu parent: I18n.t('admin.menu.finance', default: '财务管理'), label: I18n.t('admin.labels.bank_statements', default: '对账单导入'), priority: 1

  permit_params :channel, :statement_date, :status, :file

  filter :channel, as: :select, collection: -> { [
    [I18n.t('admin.reconciliation.channels.bank', default: '银行流水'), 'bank'],
    [I18n.t('admin.reconciliation.channels.alipay_disabled', default: '支付宝'), 'alipay'],
    [I18n.t('admin.reconciliation.channels.wechat_disabled', default: '微信支付'), 'wechat']
  ] }
  filter :statement_date
  filter :status, as: :select, collection: -> { BankStatement.statuses.keys }

  index do
    selectable_column
    id_column
    column :channel do |stmt|
      case stmt.channel
      when 'bank' then I18n.t('admin.reconciliation.channels.bank', default: '银行流水')
      when 'alipay' then I18n.t('admin.reconciliation.channels.alipay_disabled', default: '支付宝')
      when 'wechat' then I18n.t('admin.reconciliation.channels.wechat_disabled', default: '微信支付')
      else stmt.channel
      end
    end
    column :statement_date
    column :status do |stmt|
      status_tag stmt.status
    end
    column :file do |stmt|
      if stmt.file.attached?
        link_to I18n.t('admin.actions.download', default: '下载附件'), url_for(stmt.file)
      else
        I18n.t('admin.messages.no_file', default: '无文件')
      end
    end
    column :created_at
    actions
  end

  form do |f|
    f.inputs I18n.t('admin.reconciliation.upload_statement', default: '上传对账单') do
      f.input :channel, as: :select, collection: [
        [I18n.t('admin.reconciliation.channels.bank', default: '银行流水'), 'bank'],
        [I18n.t('admin.reconciliation.channels.alipay_disabled', default: '支付宝（未开放）'), 'alipay'],
        [I18n.t('admin.reconciliation.channels.wechat_disabled', default: '微信支付（未开放）'), 'wechat']
      ], include_blank: false,
      hint: I18n.t('admin.reconciliation.channel_hint', default: '支付宝与微信支付目前凭证申请中，暂不可选')
      f.input :statement_date, as: :datepicker
      f.input :file, as: :file
      f.input :status, as: :hidden, input_html: { value: 'pending' }
    end
    f.actions
  end

  action_item :process_batch, only: :show do
    if resource.status == 'pending' || resource.status == 'failed'
      link_to I18n.t('admin.actions.process_batch', default: '执行对账'), process_batch_admin_bank_statement_path(resource), method: :put, data: { confirm: I18n.t('admin.confirmations.process_batch', default: '确定要开始执行对账吗？') }
    end
  end

  member_action :process_batch, method: :put do
    begin
      Reconciliation::BatchProcessor.new(resource).process!
      redirect_to admin_bank_statement_path(resource), notice: I18n.t('admin.notices.batch_processed', default: '对账执行成功')
    rescue => e
      redirect_to admin_bank_statement_path(resource), alert: I18n.t('admin.alerts.batch_failed', error: e.message, default: "对账执行失败: #{e.message}")
    end
  end
end
