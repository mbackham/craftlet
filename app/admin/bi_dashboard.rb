# frozen_string_literal: true

ActiveAdmin.register_page "BiDashboard" do
  menu parent: "data_center_menu", priority: 1,
       label: proc { I18n.t("admin.bi.menu.dashboard", default: "BI 概览") }

  content title: proc { I18n.t("admin.bi.dashboard.title", default: "数据中心 — BI 概览") } do
    selected_period = (params[:period].presence || "month").to_sym
    overview = Bi::OverviewService.call(period: selected_period)
    funnel   = Bi::ConversionFunnelService.call

    # ── Period selector ──
    panel I18n.t("admin.bi.dashboard.period_selector", default: "选择周期") do
      form action: admin_bidashboard_path, method: :get, style: "display:flex; gap:8px; align-items:center;" do
        %i[week month quarter year].each do |p|
          label_text = I18n.t("admin.bi.periods.#{p}", default: p.to_s.capitalize)
          if p == selected_period
            input type: "submit", name: "period", value: p.to_s, class: "button", style: "font-weight:bold; background:#4a90d9; color:#fff;"
          else
            input type: "submit", name: "period", value: p.to_s, class: "button"
          end
        end
      end
    end

    # ── Core KPIs ──
    columns do
      column do
        panel I18n.t("admin.bi.dashboard.core_kpis", default: "核心指标") do
          attributes_table_for overview do
            row(I18n.t("admin.bi.kpi.gmv", default: "GMV (成交总额)")) { |o| number_to_currency(o.gmv, unit: "¥") }
            row(I18n.t("admin.bi.kpi.order_count", default: "订单总数")) { |o| o.order_count }
            row(I18n.t("admin.bi.kpi.paid_orders", default: "已支付订单")) { |o| o.paid_order_count }
            row(I18n.t("admin.bi.kpi.avg_order_value", default: "平均客单价")) { |o| number_to_currency(o.avg_order_value, unit: "¥") }
            row(I18n.t("admin.bi.kpi.net_income", default: "净收入")) do |o|
              color = o.net_income >= 0 ? "color:green;" : "color:red;"
              content_tag(:span, number_to_currency(o.net_income, unit: "¥"), style: color)
            end
            row(I18n.t("admin.bi.kpi.settled", default: "已结算金额")) { |o| number_to_currency(o.settled_amount, unit: "¥") }
          end
        end
      end

      column do
        panel I18n.t("admin.bi.dashboard.rates", default: "比率与增长") do
          attributes_table_for overview do
            row(I18n.t("admin.bi.kpi.user_count", default: "注册用户数")) { |o| o.user_count }
            row(I18n.t("admin.bi.kpi.merchant_count", default: "审核通过商家")) { |o| o.merchant_count }
            row(I18n.t("admin.bi.kpi.payment_success_rate", default: "支付成功率")) { |o| "#{o.payment_success_rate}%" }
            row(I18n.t("admin.bi.kpi.refund_rate", default: "退款率")) do |o|
              color = o.refund_rate > 10 ? "color:red;" : "color:green;"
              content_tag(:span, "#{o.refund_rate}%", style: color)
            end
            row(I18n.t("admin.bi.kpi.total_refund", default: "退款总额")) { |o| number_to_currency(o.total_refund, unit: "¥") }
            row(I18n.t("admin.bi.kpi.gmv_growth", default: "GMV 环比增长")) do |o|
              arrow = o.gmv_growth >= 0 ? "↑" : "↓"
              color = o.gmv_growth >= 0 ? "color:green;" : "color:red;"
              content_tag(:span, "#{arrow} #{o.gmv_growth}%", style: color)
            end
            row(I18n.t("admin.bi.kpi.order_growth", default: "订单环比增长")) do |o|
              arrow = o.order_growth >= 0 ? "↑" : "↓"
              color = o.order_growth >= 0 ? "color:green;" : "color:red;"
              content_tag(:span, "#{arrow} #{o.order_growth}%", style: color)
            end
          end
        end
      end
    end

    # ── Conversion Funnel ──
    columns do
      column do
        panel I18n.t("admin.bi.dashboard.conversion_funnel", default: "订单转化漏斗") do
          table_for funnel.stages do
            column(I18n.t("admin.bi.funnel.stage", default: "阶段")) do |s|
              I18n.t("admin.bi.funnel.stages.#{s.name}", default: s.name.humanize)
            end
            column(I18n.t("admin.bi.funnel.count", default: "数量")) { |s| s.count }
            column(I18n.t("admin.bi.funnel.rate", default: "转化率")) do |s|
              # Show a simple progress-bar style
              pct = s.rate
              content_tag(:div, style: "display:flex; align-items:center; gap:8px;") do
                bar = content_tag(:div, "", style: "width:#{[pct, 100].min}px; height:16px; background:#4a90d9; border-radius:3px;")
                text = content_tag(:span, "#{pct}%")
                bar + text
              end
            end
          end

          div style: "margin-top: 10px; padding: 8px; background: #f5f5f5; border-radius: 4px;" do
            span do
              text_node "#{I18n.t('admin.bi.funnel.canceled', default: '取消订单')}: #{funnel.canceled_count} (#{funnel.canceled_rate}%)"
            end
            span style: "margin-left: 20px;" do
              text_node "#{I18n.t('admin.bi.funnel.refunded', default: '退款订单')}: #{funnel.refunded_count} (#{funnel.refunded_rate}%)"
            end
          end
        end
      end
    end

    # ── Quick Links ──
    columns do
      column do
        panel I18n.t("admin.bi.dashboard.quick_links", default: "快速导航") do
          div style: "display: flex; gap: 15px; padding: 10px;" do
            link_to I18n.t("admin.bi.menu.trends", default: "趋势分析"), admin_bitrends_path, class: "button"
            link_to I18n.t("admin.bi.menu.merchants", default: "商家排行"), admin_bimerchants_path, class: "button"
            link_to I18n.t("admin.bi.menu.fund_report", default: "资金日报"), admin_funddailyreport_path, class: "button"
          end
        end
      end
    end
  end
end
