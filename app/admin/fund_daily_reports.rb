# frozen_string_literal: true

ActiveAdmin.register_page "FundDailyReport" do
  menu parent: "Finance menu", priority: 6,
       label: proc { I18n.t("admin.labels.fund_daily_report", default: "资金日报") }

  content title: proc { I18n.t("admin.labels.fund_daily_report", default: "资金日报") } do
    selected_date = begin
                      Date.parse(params[:date].to_s)
                    rescue ArgumentError, TypeError
                      Date.today
                    end

    report = FundMonitoring::DailyReportService.call(date: selected_date)

    # ── Date picker ──
    panel I18n.t("admin.fund_daily_report.select_date", default: "选择日期") do
      form action: admin_funddailyreport_path, method: :get do |_f|
        label I18n.t("admin.fund_daily_report.date_label", default: "日期：")
        input type: "date", name: "date", value: selected_date.to_s,
              style: "margin: 0 8px;"
        input type: "submit",
              value: I18n.t("admin.fund_daily_report.query", default: "查询"),
              class: "button"
      end
    end

    # ── Summary table ──
    columns do
      column do
        panel I18n.t("admin.fund_daily_report.summary_title",
                     date: selected_date.to_s,
                     default: "#{selected_date} 资金汇总") do
          attributes_table_for report do
            row(I18n.t("admin.fund_daily_report.date",         default: "日期"))       { |r| r.date }
            row(I18n.t("admin.fund_daily_report.income",       default: "收入总额"))   { |r| number_to_currency(r.income,       unit: "¥") }
            row(I18n.t("admin.fund_daily_report.income_count", default: "收入笔数"))   { |r| I18n.t("admin.fund_daily_report.txn_count", count: r.income_count, default: "#{r.income_count} 笔") }
            row(I18n.t("admin.fund_daily_report.refund",       default: "退款总额"))   { |r| number_to_currency(r.refund_total, unit: "¥") }
            row(I18n.t("admin.fund_daily_report.refund_count", default: "退款笔数"))   { |r| I18n.t("admin.fund_daily_report.txn_count", count: r.refund_count, default: "#{r.refund_count} 笔") }
            row(I18n.t("admin.fund_daily_report.net",          default: "净流入")) do |r|
              color = r.net >= 0 ? "color: green;" : "color: red;"
              span(style: color) { number_to_currency(r.net, unit: "¥") }
            end
            row(I18n.t("admin.fund_daily_report.settled",      default: "已结算净额")) { |r| number_to_currency(r.settled, unit: "¥") }
            row(I18n.t("admin.fund_daily_report.alert_count",  default: "大额预警数")) do |r|
              if r.alert_count > 0
                span(class: "status_tag warning") { r.alert_count.to_s }
              else
                "0"
              end
            end
          end
        end
      end
    end

    # ── Large-amount alerts for the day ──
    day_alerts = FundAlert.where(created_at: selected_date.beginning_of_day..selected_date.end_of_day)
                          .order(created_at: :desc)

    if day_alerts.any?
      panel I18n.t("admin.fund_daily_report.today_alerts_title",
                   count: day_alerts.count,
                   default: "当日大额预警 (#{day_alerts.count} 条)") do
        table_for day_alerts do
          column("ID")                                                              { |a| link_to a.id, admin_fund_alert_path(a) }
          column(I18n.t("admin.fund_daily_report.col_type",      default: "类型")) { |a| status_tag I18n.t("fund_alert_types.#{a.alert_type}", default: a.alert_type) }
          column(I18n.t("admin.fund_daily_report.col_subject",   default: "关联")) { |a| "#{a.subject_type} ##{a.subject_id}" }
          column(I18n.t("admin.fund_daily_report.col_amount",    default: "金额")) { |a| number_to_currency(a.amount,    unit: "¥") }
          column(I18n.t("admin.fund_daily_report.col_threshold", default: "阈值")) { |a| number_to_currency(a.threshold, unit: "¥") }
          column(I18n.t("admin.fund_daily_report.col_status",    default: "状态")) { |a| status_tag I18n.t("fund_alert_statuses.#{a.status}", default: a.status) }
          column(I18n.t("admin.fund_daily_report.col_time",      default: "时间")) { |a| l(a.created_at, format: :short) }
        end
      end
    else
      panel I18n.t("admin.fund_daily_report.today_alerts_title_empty", default: "当日大额预警") do
        para I18n.t("admin.fund_daily_report.no_alerts", default: "当日无大额预警记录。")
      end
    end
  end
end
