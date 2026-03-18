# frozen_string_literal: true

ActiveAdmin.register FundAlert do
  menu parent: "Finance menu", priority: 5,
       label: proc { I18n.t("admin.labels.fund_alerts", default: "大额预警") }

  actions :index, :show

  # === Scopes ===
  scope :all, default: true
  scope("待处理") { |s| s.pending }
  scope("已知晓") { |s| s.acknowledged }
  scope("已忽略") { |s| s.ignored }

  # === Filters ===
  filter :alert_type, as: :select,
         collection: FundAlert.alert_types.map { |k, _| [k.humanize, k] }
  filter :status, as: :select,
         collection: FundAlert.statuses.map { |k, _| [k.humanize, k] }
  filter :amount_gteq, label: "金额 ≥"
  filter :created_at

  # === Index ===
  index do
    selectable_column
    id_column
    column("预警类型") do |a|
      color = case a.alert_type
              when "refund" then "warning"
              when "payment" then "error"
              else nil
              end
      status_tag a.alert_type, class: color
    end
    column("关联记录") do |a|
      link_text = "#{a.subject_type} ##{a.subject_id}"
      path = case a.subject_type
             when "Payment"    then admin_payment_path(a.subject_id)
             when "Refund"     then admin_refund_path(a.subject_id)
             when "Settlement" then admin_settlement_path(a.subject_id)
             end
      path ? link_to(link_text, path) : link_text
    end
    column("金额")    { |a| number_to_currency(a.amount, unit: "¥") }
    column("阈值")    { |a| number_to_currency(a.threshold, unit: "¥") }
    column("状态") do |a|
      color = case a.status
              when "pending"      then "warning"
              when "acknowledged" then "yes"
              else nil
              end
      status_tag(I18n.t("admin.fund_alert_statuses.#{a.status}", default: a.status.humanize),
                 class: color)
    end
    column("处理人")  { |a| a.handler_admin&.email || "-" }
    column("创建时间", :created_at)
    actions name: "操作", defaults: false do |alert|
      item "查看", admin_fund_alert_path(alert)
      if alert.pending? && current_admin_user.admin_can?("finance:manage")
        item "已知晓", acknowledge_admin_fund_alert_path(alert), method: :put
        item "忽略",   ignore_admin_fund_alert_path(alert),      method: :put,
             data: { confirm: "确定忽略此大额预警？" }
      end
    end
  end

  # === Show ===
  show title: proc { |a| "大额预警 ##{a.id}" } do
    attributes_table do
      row("预警类型")  { |a| status_tag a.alert_type }
      row("关联记录") do |a|
        "#{a.subject_type} ##{a.subject_id}"
      end
      row("金额")     { |a| number_to_currency(a.amount,    unit: "¥") }
      row("阈值")     { |a| number_to_currency(a.threshold, unit: "¥") }
      row("超额倍数") { |a| "#{(a.amount / a.threshold).round(2)}x" }
      row("状态") do |a|
        color = case a.status
                when "pending"      then "warning"
                when "acknowledged" then "yes"
                else nil
                end
        status_tag a.status.humanize, class: color
      end
      row("备注")     { |a| a.note.presence || "-" }
      row("处理人")   { |a| a.handler_admin&.email || "-" }
      row("知晓时间") { |a| a.acknowledged_at ? l(a.acknowledged_at, format: :long) : "-" }
      row("创建时间") { |a| l(a.created_at, format: :long) }
    end
  end

  # === Action Items ===
  action_item :acknowledge, only: :show,
              if: proc { resource.pending? && current_admin_user.admin_can?("finance:manage") } do
    link_to "标记已知晓", acknowledge_admin_fund_alert_path(resource), method: :put
  end

  action_item :ignore, only: :show,
              if: proc { resource.pending? && current_admin_user.admin_can?("finance:manage") } do
    link_to "忽略", ignore_admin_fund_alert_path(resource),
            method: :put, data: { confirm: "确定忽略此大额预警？" }
  end

  # === Member Actions ===
  member_action :acknowledge, method: :put do
    alert = FundAlert.find(params[:id])
    alert.update!(
      status:           "acknowledged",
      handler_admin_id: current_admin_user.id,
      acknowledged_at:  Time.current
    )
    AuditService.log!(
      action: "fund_alert_acknowledge", actor: current_admin_user, target: alert,
      after: { status: "acknowledged" }, request: request
    )
    redirect_to admin_fund_alert_path(alert), notice: "已标记为知晓"
  end

  member_action :ignore, method: :put do
    alert = FundAlert.find(params[:id])
    alert.update!(
      status:           "ignored",
      handler_admin_id: current_admin_user.id
    )
    AuditService.log!(
      action: "fund_alert_ignore", actor: current_admin_user, target: alert,
      after: { status: "ignored" }, request: request
    )
    redirect_to admin_fund_alert_path(alert), notice: "已忽略预警"
  end
end
