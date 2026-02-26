# frozen_string_literal: true

ActiveAdmin.register RiskEvent do
  menu parent: "orders_menu", priority: 7, label: proc { "风控事件" }

  actions :index, :show

  # === Scopes ===
  scope :all, default: true
  scope("待处理") { |s| s.pending }
  scope("已忽略") { |s| s.ignored }
  scope("已处理") { |s| s.processed }

  # === Filters ===
  filter :risk_rule, as: :select, collection: -> { RiskRule.all.order(:name).map { |r| [r.name, r.id] } }
  filter :status, as: :select, collection: RiskEvent::STATUSES.map { |s| [s.humanize, s] }
  filter :trigger_source
  filter :created_at

  # === Index ===
  index do
    selectable_column
    id_column
    column("规则") { |e| link_to e.risk_rule.name, admin_risk_rule_path(e.risk_rule) }
    column("严重级") do |e|
      color = case e.risk_rule.severity
              when "critical" then "error"
              when "high"     then "warning"
              else nil
              end
      status_tag e.risk_rule.severity_label, class: color
    end
    column("主体") { |e| e.subject&.email || e.subject_id }
    column("触发来源", :trigger_source)
    column("状态") do |e|
      color = case e.status
              when "processed" then "yes"
              when "ignored"   then nil
              else "warning"
              end
      status_tag e.status_label, class: color
    end
    column("创建时间", :created_at)
    actions name: "操作", defaults: false do |event|
      item "查看", admin_risk_event_path(event)
      if event.status == "pending"
        item "忽略", ignore_admin_risk_event_path(event), method: :put,
             data: { confirm: "确定忽略此事件？" }
        item "处理", process_event_admin_risk_event_path(event)
      end
    end
  end

  # === Show ===
  show title: proc { |e| "风控事件 ##{e.id}" } do
    attributes_table do
      row("规则")     { |e| link_to e.risk_rule.name, admin_risk_rule_path(e.risk_rule) }
      row("严重级")   do |e|
        color = case e.risk_rule.severity
                when "critical" then "error"
                when "high"     then "warning"
                else nil
                end
        status_tag e.risk_rule.severity_label, class: color
      end
      row("主体")     { |e| e.subject&.email || e.subject_id }
      row("触发来源") { |e| e.trigger_source }
      row("状态") do |e|
        color = case e.status
                when "processed" then "yes"
                when "ignored"   then nil
                else "warning"
                end
        status_tag e.status_label, class: color
      end
      row("上下文")   { |e| pre JSON.pretty_generate(e.context) }
      row("处理备注") { |e| e.resolution_note.presence || "-" }
      row("处理人")   { |e| e.resolved_by&.email || "-" }
      row("处理时间") { |e| e.resolved_at ? l(e.resolved_at, format: :long) : "-" }
      row("创建时间") { |e| l(e.created_at, format: :long) }
    end
  end

  # === Action Items ===
  action_item :ignore, only: :show, if: proc { resource.status == "pending" } do
    link_to "忽略", ignore_admin_risk_event_path(resource),
            method: :put, data: { confirm: "确定忽略此风控事件？" }
  end

  action_item :process_event, only: :show, if: proc { resource.status == "pending" } do
    link_to "标记处理", process_event_admin_risk_event_path(resource)
  end

  # === Member Actions ===
  member_action :ignore, method: :put do
    event = RiskEvent.find(params[:id])
    event.update!(
      status:         "ignored",
      resolved_by_id: AuditService.format_as_uuid(current_admin_user.id),
      resolved_at:    Time.current
    )

    AuditService.log!(
      action: "risk_event_ignore", actor: current_admin_user, target: event,
      after: { status: "ignored" }, request: request
    )

    redirect_to admin_risk_event_path(event), notice: "事件已忽略"
  end

  member_action :process_event, method: [:get, :put] do
    @event = RiskEvent.find(params[:id])

    if request.get?
      render "admin/risk_events/process_event"
    elsif request.put?
      @event.update!(
        status:          "processed",
        resolution_note: params[:resolution_note],
        resolved_by_id:  AuditService.format_as_uuid(current_admin_user.id),
        resolved_at:     Time.current
      )

      AuditService.log!(
        action: "risk_event_process", actor: current_admin_user, target: @event,
        after: { status: "processed", resolution_note: params[:resolution_note] },
        request: request
      )

      redirect_to admin_risk_event_path(@event), notice: "事件已处理"
    end
  end
end
