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
      status_tag batch.channel
    end
    column :total_count
    column :matched_count
    column :mismatched_count
    column :status do |batch|
      status_tag batch.status
    end
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :target_date
      row :channel
      row :status do |batch|
        status_tag batch.status
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
          status_tag detail.match_status
        end
        column :process_status do |detail|
          status_tag detail.process_status
        end
      end
    end
  end
end
