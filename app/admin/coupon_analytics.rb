# frozen_string_literal: true

ActiveAdmin.register_page "CouponAnalytics" do
  menu parent: "marketing_menu", priority: 4,
       label: proc { I18n.t("admin.labels.coupon_analytics") }

  content title: proc { I18n.t("admin.labels.coupon_analytics") } do
    # Summary Stats
    total_issued  = Coupon.count
    total_used    = Coupon.used.count
    total_unused  = Coupon.unused.count
    total_expired = Coupon.expired.count
    use_rate      = total_issued.zero? ? 0 : (total_used.to_f / total_issued * 100).round(1)
    total_discount = Coupon.used.sum(:discount_amount)

    columns do
      column do
        panel I18n.t("admin.panels.overall_stats") do
          table class: "index_table" do
            tr do
              th I18n.t("admin.columns.total_issued")
              th I18n.t("admin.columns.total_used")
              th I18n.t("admin.columns.total_unused")
              th I18n.t("admin.columns.total_expired")
              th I18n.t("admin.columns.use_rate")
              th I18n.t("admin.columns.total_discount")
            end
            tr do
              td total_issued
              td total_used
              td total_unused
              td total_expired
              td "#{use_rate}%"
              td "¥#{total_discount}"
            end
          end
        end
      end
    end

    # Per-template breakdown
    panel I18n.t("admin.panels.template_breakdown") do
      templates = CouponTemplate.order(created_at: :desc)

      table class: "index_table" do
        thead do
          tr do
            th "ID"
            th I18n.t("admin.columns.name")
            th I18n.t("admin.columns.coupon_type")
            th I18n.t("admin.columns.issued_count")
            th I18n.t("admin.columns.used_count")
            th I18n.t("admin.columns.use_rate")
            th I18n.t("admin.columns.total_discount")
            th I18n.t("admin.columns.quota_progress")
            th I18n.t("admin.columns.budget_progress")
          end
        end
        tbody do
          templates.each do |tmpl|
            issued  = tmpl.coupons.count
            used    = tmpl.coupons.used.count
            rate    = issued.zero? ? 0 : (used.to_f / issued * 100).round(1)
            discount_sum = tmpl.coupons.used.sum(:discount_amount)

            tr do
              td tmpl.id
              td link_to(tmpl.name, admin_coupon_template_path(tmpl))
              td I18n.t("coupon_types.#{tmpl.coupon_type}")
              td issued
              td used
              td "#{rate}%"
              td "¥#{discount_sum}"
              td do
                if tmpl.total_quota
                  "#{tmpl.issued_count}/#{tmpl.total_quota} (#{(tmpl.quota_used_ratio * 100).round(1)}%)"
                else
                  "#{tmpl.issued_count}/∞"
                end
              end
              td do
                if tmpl.budget_amount
                  "¥#{tmpl.used_amount}/¥#{tmpl.budget_amount} (#{(tmpl.budget_used_ratio * 100).round(1)}%)"
                else
                  "¥#{tmpl.used_amount}/∞"
                end
              end
            end
          end
        end
      end
    end

    # Recent 7-day trend
    panel I18n.t("admin.panels.recent_trend") do
      rows = (6.downto(0)).map do |days_ago|
        date    = days_ago.days.ago.to_date
        issued  = Coupon.where(granted_at: date.all_day).count
        used    = Coupon.used.where(used_at: date.all_day).count
        discount = Coupon.used.where(used_at: date.all_day).sum(:discount_amount)
        [date, issued, used, discount]
      end

      table class: "index_table" do
        thead do
          tr do
            th I18n.t("admin.columns.date")
            th I18n.t("admin.columns.issued_count")
            th I18n.t("admin.columns.used_count")
            th I18n.t("admin.columns.discount_amount")
          end
        end
        tbody do
          rows.each do |date, issued, used, discount|
            tr do
              td date
              td issued
              td used
              td "¥#{discount}"
            end
          end
        end
      end
    end

    # Pending budget alerts
    pending_alerts = CouponBudgetAlert.pending.includes(:coupon_template).order(created_at: :desc)
    if pending_alerts.any?
      panel I18n.t("admin.panels.pending_budget_alerts") do
        table class: "index_table" do
          thead do
            tr do
              th "ID"
              th I18n.t("admin.columns.template")
              th I18n.t("admin.columns.alert_type")
              th I18n.t("admin.columns.current_ratio")
              th I18n.t("admin.columns.created_time")
              th I18n.t("admin.columns.actions")
            end
          end
          tbody do
            pending_alerts.each do |alert|
              tr do
                td alert.id
                td link_to(alert.coupon_template.name, admin_coupon_template_path(alert.coupon_template))
                td I18n.t("coupon_alert_types.#{alert.alert_type}")
                td "#{(alert.current_ratio * 100).round(1)}%"
                td alert.created_at.strftime("%Y-%m-%d %H:%M")
                td link_to(I18n.t("admin.actions.acknowledge_alert"),
                            acknowledge_admin_coupon_budget_alert_path(alert),
                            method: :put,
                            data: { confirm: I18n.t("admin.confirmations.acknowledge_alert") },
                            class: "button")
              end
            end
          end
        end
      end
    end
  end
end
