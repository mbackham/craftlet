# frozen_string_literal: true

ActiveAdmin.register_page "EtlDashboard" do
  menu parent: "etl_menu", priority: 0,
       label: proc { I18n.t("admin.etl.menu.dashboard", default: "ETL 总览") }

  content title: proc { I18n.t("admin.etl.dashboard.title", default: "ETL 数据仓库总览") } do

    # === KPI Overview ===
    columns do
      column do
        panel I18n.t("admin.etl.dashboard.sync_stats", default: "同步状态") do
          last_logs = EtlSyncLog.order(created_at: :desc).limit(7)
          attributes_table_for OpenStruct.new(
            total_syncs:    EtlSyncLog.count,
            completed:      EtlSyncLog.completed.count,
            failed:         EtlSyncLog.failed.count,
            running:        EtlSyncLog.running.count,
            fact_orders:    DwFactOrder.count,
            fact_payments:  DwFactPayment.count,
            fact_refunds:   DwFactRefund.count,
            dim_users:      DwDimUser.count,
            dim_merchants:  DwDimMerchant.count
          ) do
            row(I18n.t("admin.etl.dashboard.total_syncs", default: "同步总次数")) { |s| s.total_syncs }
            row(I18n.t("admin.etl.dashboard.completed", default: "成功")) { |s| s.completed }
            row(I18n.t("admin.etl.dashboard.failed", default: "失败")) do |s|
              color = s.failed > 0 ? "color:red;" : "color:green;"
              content_tag(:span, s.failed, style: color)
            end
            row(I18n.t("admin.etl.dashboard.running", default: "运行中")) { |s| s.running }
          end
        end
      end

      column do
        panel I18n.t("admin.etl.dashboard.dw_stats", default: "数仓数据量") do
          attributes_table_for OpenStruct.new(
            fact_orders:    DwFactOrder.count,
            fact_payments:  DwFactPayment.count,
            fact_refunds:   DwFactRefund.count,
            fact_settle:    DwFactSettlement.count,
            fact_coupons:   DwFactCoupon.count,
            dim_users:      DwDimUser.count,
            dim_merchants:  DwDimMerchant.count,
            clean_rules:    EtlCleanRule.active.count,
            lineage_nodes:  EtlLineageNode.active.count
          ) do
            row("dw_fact_orders") { |s| s.fact_orders }
            row("dw_fact_payments") { |s| s.fact_payments }
            row("dw_fact_refunds") { |s| s.fact_refunds }
            row("dw_fact_settlements") { |s| s.fact_settle }
            row("dw_fact_coupons") { |s| s.fact_coupons }
            row("dw_dim_users") { |s| s.dim_users }
            row("dw_dim_merchants") { |s| s.dim_merchants }
            row(I18n.t("admin.etl.dashboard.clean_rules", default: "活跃清洗规则")) { |s| s.clean_rules }
            row(I18n.t("admin.etl.dashboard.lineage_nodes", default: "血缘节点")) { |s| s.lineage_nodes }
          end
        end
      end
    end

    # === Recent Sync Jobs ===
    panel I18n.t("admin.etl.dashboard.recent_syncs", default: "最近同步记录") do
      table_for EtlSyncLog.recent.limit(10) do
        column :source_table
        column :sync_type
        column :status do |log|
          status_tag log.status, class: { 'completed' => :ok, 'failed' => :error, 'running' => :warning }[log.status]
        end
        column :extracted_count
        column :loaded_count
        column :cleaned_count
        column I18n.t("admin.etl.sync_log.duration", default: "耗时(秒)") do |log|
          log.duration_seconds
        end
        column :started_at
      end
    end

    # === RFM Distribution ===
    columns do
      column do
        panel I18n.t("admin.etl.dashboard.rfm_distribution", default: "用户RFM分层") do
          rfm_stats = DwDimUser.group(:rfm_segment).count
          table do
            DwDimUser::RFM_SEGMENTS.each do |seg|
              tr do
                td seg
                td rfm_stats[seg].to_i
              end
            end
          end
        end
      end

      column do
        panel I18n.t("admin.etl.dashboard.merchant_tier", default: "商家层级分布") do
          tier_stats = DwDimMerchant.group(:merchant_tier).count
          table do
            DwDimMerchant::MERCHANT_TIERS.each do |tier|
              tr do
                td tier
                td tier_stats[tier].to_i
              end
            end
          end
        end
      end
    end

    # === Quick Actions ===
    panel I18n.t("admin.etl.dashboard.quick_actions", default: "快速操作") do
      div style: "display: flex; gap: 15px; padding: 10px; flex-wrap: wrap;" do
        link_to I18n.t("admin.etl.menu.sync_logs", default: "同步任务"), admin_etl_sync_logs_path, class: "button"
        link_to I18n.t("admin.etl.menu.clean_rules", default: "清洗规则"), admin_etl_clean_rules_path, class: "button"
        link_to I18n.t("admin.etl.menu.clean_logs", default: "清洗日志"), admin_etl_clean_logs_path, class: "button"
        link_to I18n.t("admin.etl.menu.dim_users", default: "用户画像"), admin_dw_dim_users_path, class: "button"
        link_to I18n.t("admin.etl.menu.dim_merchants", default: "商家画像"), admin_dw_dim_merchants_path, class: "button"
        link_to I18n.t("admin.etl.menu.lineage", default: "血缘图"), admin_etllineage_path, class: "button"
      end
    end
  end
end
