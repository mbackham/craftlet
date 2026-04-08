# frozen_string_literal: true
ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    # 计算核心指标
    # GMV: 所有已支付及后续状态的订单总额
    gmv = Order.where(status: %w[paid accepted producing delivered completed refunded]).sum(:total_amount) || 0
    
    # 退款总额: 所有成功的退款总额
    refund_total = Refund.where(status: "succeeded").sum(:amount) || 0
    
    # 退款率 = 退款总额 / GMV
    refund_rate = gmv > 0 ? (refund_total / gmv * 100).round(2) : 0.0

    columns do
      column do
        panel I18n.t("admin.panels.core_metrics", default: "运营核心数据 (GMV)") do
          attributes_table_for "Metrics" do
            row(I18n.t("admin.columns.gmv", default: "成交总额 (GMV)")) { number_to_currency(gmv, unit: "¥") }
            row(I18n.t("admin.columns.total_refund", default: "成功退款总额")) { number_to_currency(refund_total, unit: "¥") }
            row(I18n.t("admin.columns.refund_rate", default: "整体退款率")) { "#{refund_rate}%" }
          end
        end
      end

      column do
        panel I18n.t("admin.panels.order_status_distribution", default: "订单状态分布") do
          status_counts = Order.group(:status).count
          
          if status_counts.any?
            table_for status_counts.to_a do
              column(I18n.t("admin.columns.status")) do |status, _|
                status_color = case status.to_s
                               when 'completed' then 'yes'
                               when 'canceled', 'refunded' then 'error'
                               when 'paid', 'accepted' then 'warning'
                               else nil
                               end
                status_tag I18n.t("order_statuses.#{status}", default: status.to_s.humanize), class: status_color
              end
              column(I18n.t("admin.columns.order_count", default: "订单数量")) { |_, count| count }
            end
          else
            para I18n.t("admin.messages.no_orders_yet", default: "暂无订单数据。")
          end
        end
      end
    end
    
    # 结算概览
    columns do
      column do
        panel I18n.t("admin.panels.settlement_overview", default: "结算概览") do
          pending_settlements = Settlement.where(status: "pending_review").count
          monthly_settled = Settlement.where(status: "confirmed")
                                      .where("confirmed_at >= ?", Time.current.beginning_of_month)
                                      .sum(:net_amount)
          pending_exceptions = SettlementException.where(status: %w[pending processing]).count

          attributes_table_for "Settlement" do
            row(I18n.t("admin.columns.pending_review_count", default: "待审批结算单")) { pending_settlements }
            row(I18n.t("admin.columns.monthly_settled", default: "本月已结算总额")) { number_to_currency(monthly_settled, unit: "¥") }
            row(I18n.t("admin.columns.pending_exceptions", default: "待处理异常")) { pending_exceptions }
          end

          div style: "display: flex; gap: 10px; margin-top: 10px;" do
            link_to I18n.t("admin.actions.settlement_list", default: "结算单列表"), admin_settlements_path, class: "button"
            link_to I18n.t("admin.actions.settlement_rules", default: "结算规则"), admin_settlement_rules_path, class: "button"
            link_to I18n.t("admin.actions.invoice_management", default: "发票管理"), admin_invoices_path, class: "button"
          end
        end
      end
    end

    # 对账概览
    columns do
      column do
        panel I18n.t("admin.panels.reconciliation_overview", default: "对账概览") do
          today_batch = ReconciliationBatch.where(target_date: Date.today).last
          pending_count = ReconciliationDetail.where(process_status: 'pending').count

          attributes_table_for "Reconciliation" do
            row(I18n.t("admin.columns.pending_discrepancies", default: "待处理差异")) { pending_count }
            row(I18n.t("admin.columns.today_batch_status", default: "今日对账状态")) do
              if today_batch
                status_tag today_batch.status
              else
                I18n.t("admin.messages.no_reconciliation_today", default: "今日尚未执行对账")
              end
            end
          end

          # 近7日差异走势
          recent_batches = ReconciliationBatch.where(target_date: 7.days.ago.to_date..Date.today).order(:target_date)
          if recent_batches.any?
            table_for recent_batches do
              column(I18n.t("admin.columns.target_date", default: "对账日期")) { |b| b.target_date }
              column(I18n.t("admin.columns.total_count", default: "总笔数")) { |b| b.total_count }
              column(I18n.t("admin.columns.matched_count", default: "平账")) { |b| b.matched_count }
              column(I18n.t("admin.columns.mismatched_count", default: "异常")) { |b| b.mismatched_count }
              column(I18n.t("admin.columns.status")) { |b| status_tag b.status }
            end
          end
        end
      end
    end

    # 资金监控概览
    columns do
      column do
        panel I18n.t("admin.panels.fund_monitoring", default: "资金监控") do
          # 今日资金日报
          today_report = FundMonitoring::DailyReportService.call(date: Date.today)
          pending_alerts = FundAlert.pending.count
          today_alerts   = FundAlert.today.count

          attributes_table_for "FundMonitoring" do
            row(I18n.t("admin.columns.today_income",        default: "今日收入")) { number_to_currency(today_report.income,       unit: "¥") }
            row(I18n.t("admin.columns.today_refund",        default: "今日退款")) { number_to_currency(today_report.refund_total, unit: "¥") }
            row(I18n.t("admin.columns.today_net",           default: "今日净流入")) do
              color = today_report.net >= 0 ? "color:green;" : "color:red;"
              content_tag(:span, number_to_currency(today_report.net, unit: "¥"), style: color)
            end
            row(I18n.t("admin.columns.today_alerts",        default: "今日大额预警")) do
              today_alerts > 0 ? status_tag("#{today_alerts} 条", class: "warning") : "0 条"
            end
            row(I18n.t("admin.columns.pending_fund_alerts", default: "待处理大额预警")) do
              pending_alerts > 0 ? status_tag("#{pending_alerts} 条", class: "error") : "0 条"
            end
          end

          div style: "display: flex; gap: 10px; margin-top: 10px;" do
            link_to I18n.t("admin.actions.fund_alerts_list", default: "大额预警列表"),  admin_fund_alerts_path,        class: "button"
            link_to I18n.t("admin.actions.fund_daily_report_list", default: "资金日报"),      admin_funddailyreport_path,    class: "button"
            link_to I18n.t("admin.actions.risk_events", default: "风控事件"),      admin_risk_events_path,        class: "button"
          end
        end
      end
    end

    # 底部快捷入口
    columns do
      column do
        panel I18n.t("admin.panels.quick_links", default: "对账快捷出口 (点击跳转后可根据时间筛选并导出 CSV)") do
          div style: "display: flex; gap: 15px; padding: 10px;" do
            link_to I18n.t("admin.actions.export_orders", default: "前往订单列表 (支持导出)"), admin_orders_path, class: "button"
            link_to I18n.t("admin.actions.export_refunds", default: "前往退款列表 (支持导出)"), admin_refunds_path, class: "button"
            link_to I18n.t("admin.actions.goto_reconciliation", default: "前往对账差异处理"), admin_reconciliation_details_path, class: "button"
            link_to I18n.t("admin.actions.goto_bank_statements", default: "前往对账单导入"), admin_bank_statements_path, class: "button"
          end
        end
      end
    end
  end # content
end
