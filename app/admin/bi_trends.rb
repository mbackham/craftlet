# frozen_string_literal: true

ActiveAdmin.register_page "BiTrends" do
  menu parent: "data_center_menu", priority: 2,
       label: proc { I18n.t("admin.bi.menu.trends", default: "趋势分析") }

  content title: proc { I18n.t("admin.bi.trends.title", default: "数据中心 — 趋势分析") } do
    start_date = begin
                   Date.parse(params[:start_date].to_s)
                 rescue ArgumentError, TypeError
                   30.days.ago.to_date
                 end
    end_date = begin
                 Date.parse(params[:end_date].to_s)
               rescue ArgumentError, TypeError
                 Date.today
               end
    group_by = (params[:group_by].presence || "day").to_sym

    result = Bi::TrendService.call(start_date: start_date, end_date: end_date, group_by: group_by)

    # ── Filters ──
    panel I18n.t("admin.bi.trends.filters", default: "筛选条件") do
      form action: admin_bitrends_path, method: :get, style: "display:flex; gap:12px; align-items:center; flex-wrap:wrap;" do
        label I18n.t("admin.bi.trends.start_date", default: "开始日期：")
        input type: "date", name: "start_date", value: start_date.to_s
        label I18n.t("admin.bi.trends.end_date", default: "结束日期：")
        input type: "date", name: "end_date", value: end_date.to_s
        label I18n.t("admin.bi.trends.group_by_label", default: "聚合维度：")
        select name: "group_by" do
          %i[day week month].each do |g|
            option(value: g, selected: (g == group_by ? "selected" : nil)) do
              I18n.t("admin.bi.trends.group_by.#{g}", default: g.to_s.capitalize)
            end
          end
        end
        input type: "submit", value: I18n.t("admin.bi.trends.query", default: "查询"), class: "button"

        # Preset buttons
        span style: "margin-left:10px;" do
          text_node I18n.t("admin.bi.trends.presets", default: "快捷选择：")
        end
        { "7d" => 7, "30d" => 30, "90d" => 90 }.each do |label_text, days|
          link_to label_text,
                  admin_bitrends_path(start_date: days.days.ago.to_date, end_date: Date.today, group_by: group_by),
                  class: "button"
        end
      end
    end

    # ── Summary ──
    columns do
      column do
        panel I18n.t("admin.bi.trends.summary", default: "汇总统计") do
          s = result.summary
          attributes_table_for s do
            row(I18n.t("admin.bi.trends.total_gmv", default: "总 GMV")) { |x| number_to_currency(x.total_gmv, unit: "¥") }
            row(I18n.t("admin.bi.trends.total_orders", default: "总订单数")) { |x| x.total_orders }
            row(I18n.t("admin.bi.trends.total_refunds", default: "总退款额")) { |x| number_to_currency(x.total_refunds, unit: "¥") }
            row(I18n.t("admin.bi.trends.total_net", default: "净收入")) do |x|
              color = x.total_net >= 0 ? "color:green;" : "color:red;"
              content_tag(:span, number_to_currency(x.total_net, unit: "¥"), style: color)
            end
            row(I18n.t("admin.bi.trends.avg_daily_gmv", default: "日均 GMV")) { |x| number_to_currency(x.avg_daily_gmv, unit: "¥") }
          end
        end
      end
    end

    # ── Trend Data Table ──
    columns do
      column do
        panel I18n.t("admin.bi.trends.detail_table", default: "趋势明细") do
          if result.points.any?
            table_for result.points do
              column(I18n.t("admin.bi.trends.date_col", default: "日期")) { |p| p.date }
              column(I18n.t("admin.bi.trends.gmv_col", default: "GMV")) { |p| number_to_currency(p.gmv, unit: "¥") }
              column(I18n.t("admin.bi.trends.orders_col", default: "订单")) { |p| p.order_count }
              column(I18n.t("admin.bi.trends.refund_col", default: "退款")) { |p| number_to_currency(p.refund_amount, unit: "¥") }
              column(I18n.t("admin.bi.trends.net_col", default: "净收入")) do |p|
                color = p.net_income >= 0 ? "color:green;" : "color:red;"
                content_tag(:span, number_to_currency(p.net_income, unit: "¥"), style: color)
              end
            end
          else
            para I18n.t("admin.bi.trends.no_data", default: "所选区间暂无数据。")
          end
        end
      end
    end
  end
end
