# frozen_string_literal: true

ActiveAdmin.register_page "BiMerchants" do
  menu parent: "data_center_menu", priority: 3,
       label: proc { I18n.t("admin.bi.menu.merchants", default: "商家排行") }

  content title: proc { I18n.t("admin.bi.merchants.title", default: "数据中心 — 商家排行") } do
    selected_metric = (params[:metric].presence || "gmv").to_sym
    selected_period = (params[:period].presence || "month").to_sym
    limit           = (params[:limit].presence || 10).to_i

    rankings = Bi::MerchantRankingService.call(metric: selected_metric, period: selected_period, limit: limit)

    # Also fetch refund analysis for the refund merchant panel
    start_date = case selected_period
                 when :week then 7.days.ago.to_date
                 when :quarter then 90.days.ago.to_date
                 when :year then 365.days.ago.to_date
                 else 30.days.ago.to_date
                 end
    refund_analysis = Bi::RefundAnalysisService.call(start_date: start_date, end_date: Date.today, merchant_limit: limit)

    # ── Filters ──
    panel I18n.t("admin.bi.merchants.filters", default: "筛选条件") do
      form action: admin_bimerchants_path, method: :get,
           style: "display:flex; gap:12px; align-items:center; flex-wrap:wrap;" do
        label I18n.t("admin.bi.merchants.metric_label", default: "排序指标：")
        select name: "metric" do
          %i[gmv order_count refund_rate].each do |m|
            option(value: m, selected: (m == selected_metric ? "selected" : nil)) do
              I18n.t("admin.bi.merchants.metrics.#{m}", default: m.to_s.humanize)
            end
          end
        end

        label I18n.t("admin.bi.merchants.period_label", default: "周期：")
        select name: "period" do
          %i[week month quarter year].each do |p|
            option(value: p, selected: (p == selected_period ? "selected" : nil)) do
              I18n.t("admin.bi.periods.#{p}", default: p.to_s.capitalize)
            end
          end
        end

        label I18n.t("admin.bi.merchants.limit_label", default: "显示前：")
        select name: "limit" do
          [5, 10, 20, 50].each do |n|
            option(value: n, selected: (n == limit ? "selected" : nil)) { "#{n}" }
          end
        end

        input type: "submit", value: I18n.t("admin.bi.merchants.query", default: "查询"), class: "button"
      end
    end

    # ── Merchant Rankings ──
    columns do
      column do
        panel I18n.t("admin.bi.merchants.ranking_title", default: "商家排行榜") do
          if rankings.any?
            table_for rankings do
              column(I18n.t("admin.bi.merchants.col_rank", default: "排名")) { |m| m.rank }
              column(I18n.t("admin.bi.merchants.col_shop", default: "店铺名称")) { |m| m.shop_name }
              column(I18n.t("admin.bi.merchants.col_gmv", default: "GMV")) { |m| number_to_currency(m.gmv, unit: "¥") }
              column(I18n.t("admin.bi.merchants.col_orders", default: "订单数")) { |m| m.order_count }
              column(I18n.t("admin.bi.merchants.col_refund_amount", default: "退款额")) { |m| number_to_currency(m.refund_amount, unit: "¥") }
              column(I18n.t("admin.bi.merchants.col_refund_rate", default: "退款率")) do |m|
                color = m.refund_rate > 10 ? "color:red;" : "color:green;"
                content_tag(:span, "#{m.refund_rate}%", style: color)
              end
            end
          else
            para I18n.t("admin.bi.merchants.no_data", default: "暂无商家数据。")
          end
        end
      end
    end

    # ── Refund Analysis ──
    columns do
      column do
        panel I18n.t("admin.bi.merchants.refund_overview", default: "退款分析概览") do
          attributes_table_for refund_analysis do
            row(I18n.t("admin.bi.refund.total_count", default: "退款总笔数")) { |r| r.total_refund_count }
            row(I18n.t("admin.bi.refund.total_amount", default: "退款总额")) { |r| number_to_currency(r.total_refund_amount, unit: "¥") }
            row(I18n.t("admin.bi.refund.rate", default: "退款率")) do |r|
              color = r.refund_rate > 10 ? "color:red;" : "color:green;"
              content_tag(:span, "#{r.refund_rate}%", style: color)
            end
            row(I18n.t("admin.bi.refund.avg_amount", default: "平均退款金额")) { |r| number_to_currency(r.avg_refund_amount, unit: "¥") }
          end
        end
      end

      column do
        panel I18n.t("admin.bi.merchants.refund_reasons", default: "退款原因分布") do
          if refund_analysis.reason_breakdown.any?
            table_for refund_analysis.reason_breakdown do
              column(I18n.t("admin.bi.refund.reason", default: "原因")) { |r| r.reason }
              column(I18n.t("admin.bi.refund.reason_count", default: "笔数")) { |r| r.count }
              column(I18n.t("admin.bi.refund.reason_amount", default: "金额")) { |r| number_to_currency(r.amount, unit: "¥") }
              column(I18n.t("admin.bi.refund.reason_pct", default: "占比")) { |r| "#{r.percentage}%" }
            end
          else
            para I18n.t("admin.bi.refund.no_reasons", default: "暂无退款原因数据。")
          end
        end
      end
    end

    # ── Top Refund Merchants ──
    columns do
      column do
        panel I18n.t("admin.bi.merchants.top_refund_merchants", default: "退款额 TOP 商家 (风险关注)") do
          if refund_analysis.top_refund_merchants.any?
            table_for refund_analysis.top_refund_merchants do
              column(I18n.t("admin.bi.merchants.col_shop", default: "店铺名称")) { |m| m.shop_name }
              column(I18n.t("admin.bi.refund.merchant_refund_count", default: "退款笔数")) { |m| m.refund_count }
              column(I18n.t("admin.bi.refund.merchant_refund_amount", default: "退款金额")) { |m| number_to_currency(m.refund_amount, unit: "¥") }
              column(I18n.t("admin.bi.merchants.col_refund_rate", default: "退款率")) do |m|
                color = m.refund_rate > 10 ? "color:red;" : "color:green;"
                content_tag(:span, "#{m.refund_rate}%", style: color)
              end
            end
          else
            para I18n.t("admin.bi.merchants.no_data", default: "暂无商家数据。")
          end
        end
      end
    end
  end
end
