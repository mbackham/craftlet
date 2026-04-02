# frozen_string_literal: true

ActiveAdmin.register EtlSyncLog do
  menu parent: "etl_menu", priority: 1,
       label: proc { I18n.t("admin.etl.menu.sync_logs", default: "同步任务") }

  actions :index, :show

  filter :source_table, as: :string
  filter :status, as: :select, collection: EtlSyncLog::STATUSES
  filter :sync_type, as: :select, collection: EtlSyncLog::SYNC_TYPES
  filter :started_at, as: :date_range
  filter :batch_id, as: :string

  index do
    column I18n.t("admin.etl.sync_log.batch_id", default: "批次ID"), :batch_id
    column I18n.t("admin.etl.sync_log.source_table", default: "源表") do |log|
      I18n.t("admin.etl.sources.#{log.source_table}", default: log.source_table)
    end
    column I18n.t("admin.etl.sync_log.target_table", default: "目标表"), :target_table
    column I18n.t("admin.etl.sync_log.sync_type", default: "类型"), :sync_type
    column I18n.t("admin.etl.sync_log.status", default: "状态") do |log|
      status_tag log.status, class: { 'completed' => :ok, 'failed' => :error, 'running' => :warning }[log.status]
    end
    column I18n.t("admin.etl.sync_log.extracted", default: "抽取数"), :extracted_count
    column I18n.t("admin.etl.sync_log.loaded", default: "加载数"), :loaded_count
    column I18n.t("admin.etl.sync_log.cleaned", default: "清洗数"), :cleaned_count
    column I18n.t("admin.etl.sync_log.duration", default: "耗时(秒)") do |log|
      log.duration_seconds
    end
    column :started_at
    actions
  end

  show do
    attributes_table do
      row :batch_id
      row :source_table
      row :target_table
      row :sync_type
      row :status do |log|
        status_tag log.status
      end
      row :extracted_count
      row :loaded_count
      row :cleaned_count
      row :error_count
      row :started_at
      row :completed_at
      row I18n.t("admin.etl.sync_log.duration", default: "耗时(秒)") do |log|
        log.duration_seconds
      end
      row :error_message
      row :metadata do |log|
        pre log.metadata.to_json
      end
    end
  end

  action_item :trigger_sync, only: :index do
    link_to I18n.t("admin.etl.actions.trigger_full_sync", default: "触发全量同步"),
            trigger_full_sync_admin_etl_sync_logs_path,
            method: :post,
            class: "button",
            data: { confirm: I18n.t("admin.etl.confirm.full_sync", default: "确认触发全量同步？") }
  end

  collection_action :trigger_full_sync, method: :post do
    Etl::FullSyncJob.perform_later
    redirect_to admin_etl_sync_logs_path, notice: I18n.t("admin.etl.notices.full_sync_enqueued", default: "全量同步任务已加入队列")
  end

  Etl::Pipeline.all_sources.each do |source|
    action_item :"sync_#{source}", only: :index do
      link_to I18n.t("admin.etl.actions.sync_source", default: "同步 %{source}", source: source),
              trigger_source_sync_admin_etl_sync_logs_path(source: source),
              method: :post,
              class: "button"
    end
  end

  collection_action :trigger_source_sync, method: :post do
    source = params[:source]
    if Etl::Pipeline.all_sources.include?(source)
      Etl::SyncJob.perform_later(source)
      redirect_to admin_etl_sync_logs_path, notice: "已触发 #{source} 同步任务"
    else
      redirect_to admin_etl_sync_logs_path, alert: "未知数据源: #{source}"
    end
  end
end
