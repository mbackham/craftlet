ActiveAdmin.register ReconciliationBatch do
  menu parent: I18n.t('admin.menu.finance', default: '财务管理'), label: -> { I18n.t('admin.labels.reconciliation_batches', default: '对账批次') }, priority: 2

  actions :index, :show

  filter :target_date
  filter :channel
  filter :status

  index do
    id_column
    column :target_date
    column :channel do |batch|
      status_tag I18n.t("payment_channels.#{batch.channel == 'bank' ? 'bank_transfer' : batch.channel}", default: batch.channel.to_s.titleize), class: batch.channel
    end
    column :total_count
    column :matched_count
    column :mismatched_count
    column :status do |batch|
      status_tag I18n.t("processing_statuses.#{batch.status}", default: batch.status.to_s.titleize), class: batch.status
    end
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :target_date
      row :channel do |batch|
        status_tag I18n.t("payment_channels.#{batch.channel == 'bank' ? 'bank_transfer' : batch.channel}", default: batch.channel.to_s.titleize), class: batch.channel
      end
      row :status do |batch|
        status_tag I18n.t("processing_statuses.#{batch.status}", default: batch.status.to_s.titleize), class: batch.status
      end
      row :total_count
      row :matched_count
      row :mismatched_count
      row :created_at
    end

    panel I18n.t('admin.panels.batch_discrepancies', default: '当前批次差异明细') do
      table_for resource.reconciliation_details.where.not(match_status: 'matched') do
        column :id do |detail|
          link_to detail.id, admin_reconciliation_detail_path(detail)
        end
        column :transaction_no
        column :order_no
        column :system_amount
        column :statement_amount
        column :match_status do |detail|
          status_tag I18n.t("match_statuses.#{detail.match_status}", default: detail.match_status.to_s.titleize), class: detail.match_status == 'matched' ? 'ok' : 'error'
        end
        column :process_status do |detail|
          status_tag I18n.t("process_statuses.#{detail.process_status}", default: detail.process_status.to_s.titleize), class: case detail.process_status when 'pending' then 'error' when 'claimed' then 'warn' else 'ok' end
        end
      end
    end
  end
end
