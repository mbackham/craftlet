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
    
    # 底部快捷入口
    columns do
      column do
        panel I18n.t("admin.panels.quick_links", default: "对账快捷出口 (点击跳转后可根据时间筛选并导出 CSV)") do
          div style: "display: flex; gap: 15px; padding: 10px;" do
            link_to I18n.t("admin.actions.export_orders", default: "前往订单列表 (支持导出)"), admin_orders_path, class: "button"
            link_to I18n.t("admin.actions.export_refunds", default: "前往退款列表 (支持导出)"), admin_refunds_path, class: "button"
          end
        end
      end
    end
  end # content
end
