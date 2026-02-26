# frozen_string_literal: true

ActiveAdmin.register Refund do
  menu parent: "orders_menu", priority: 3, label: proc { I18n.t("admin.labels.refunds") }

  # Read-only CRUD; approve/reject via member actions
  actions :index, :show

  # === Authorization ===
  # Pundit will use RefundPolicy automatically

  # === Scopes ===
  scope :all, default: true
  scope proc { I18n.t("admin.scopes.pending_review") }, :pending_review do |scope|
    scope.where(status: "init")
  end
  scope proc { I18n.t("admin.scopes.processing") }, :processing do |scope|
    scope.where(status: "pending")
  end
  scope proc { I18n.t("admin.scopes.succeeded") }, :succeeded do |scope|
    scope.where(status: "succeeded")
  end
  scope proc { I18n.t("admin.scopes.failed") }, :failed do |scope|
    scope.where(status: "failed")
  end

  # === Filters ===
  filter :order_id
  filter :payment_id
  filter :status, as: :select, collection: Refund::STATUSES.map { |s|
    [I18n.t("refund_statuses.#{s}", default: s.humanize), s]
  }
  filter :amount
  filter :reason
  filter :provider_refund_no
  filter :succeeded_at
  filter :created_at

  # === Index ===
  index do
    selectable_column
    id_column
    column I18n.t("admin.columns.related_order") do |refund|
      link_to refund.order.order_no, admin_order_path(refund.order) if refund.order
    end
    column I18n.t("admin.columns.related_payment") do |refund|
      link_to "##{refund.payment_id}", admin_payment_path(refund.payment) if refund.payment
    end
    column I18n.t("admin.columns.amount") do |refund|
      number_to_currency(refund.amount, unit: "¥")
    end
    column I18n.t("admin.columns.reason"), :reason
    column I18n.t("admin.columns.status") do |refund|
      status_color = case refund.status
                     when "succeeded" then "yes"
                     when "failed"    then "error"
                     when "pending"   then "warning"
                     when "init"      then nil
                     end
      status_tag refund.status_label, class: status_color
    end
    column I18n.t("admin.columns.success_time"), :succeeded_at
    column I18n.t("admin.columns.created_time"), :created_at
    actions name: I18n.t("admin.columns.actions"), defaults: false do |refund|
      item I18n.t("admin.actions.view"), admin_refund_path(refund)
      if refund.status == "init" && current_admin_user.admin_can?("refund:approve")
        item I18n.t("admin.actions.approve_refund"),
             approve_admin_refund_path(refund),
             method: :put,
             data: { confirm: I18n.t("admin.confirmations.approve_refund") }
        item I18n.t("admin.actions.reject_refund"),
             reject_admin_refund_path(refund)
      end
    end
  end

  # === Show ===
  show title: proc { |r| I18n.t("admin.titles.refund_record", id: r.id) } do
    attributes_table do
      row("ID") { |r| r.id }
      row(I18n.t("admin.columns.related_order")) { |r| link_to r.order.order_no, admin_order_path(r.order) if r.order }
      row(I18n.t("admin.columns.related_payment")) { |r| link_to "##{r.payment_id}", admin_payment_path(r.payment) if r.payment }
      row(I18n.t("admin.columns.amount")) { |r| number_to_currency(r.amount, unit: "¥") }
      row(I18n.t("admin.columns.refund_request_reason")) { |r| r.reason.presence || I18n.t("admin.messages.not_filled") }
      row(I18n.t("admin.columns.status")) do |r|
        status_color = case r.status
                       when "succeeded" then "yes"
                       when "failed"    then "error"
                       when "pending"   then "warning"
                       else nil
                       end
        status_tag r.status_label, class: status_color
      end
      row(:provider_refund_no) { |r| r.provider_refund_no.presence || I18n.t("admin.messages.not_filled") }
      row(:idempotency_key)    { |r| r.idempotency_key }
      row(:requester)          { |r| r.requester&.email || r.requested_by_id }
      row(I18n.t("admin.columns.success_time")) { |r| l(r.succeeded_at, format: :long) if r.succeeded_at }
      row(:created_at)         { |r| l(r.created_at, format: :long) if r.created_at }
    end

    # 拒绝信息面板（仅当退款被拒绝时显示）
    if refund.status == "failed"
      reject_log = AuditLog.where(target_type: "Refund", target_id: refund.id, action: "reject")
                           .order(created_at: :desc).first

      panel I18n.t("admin.panels.refund_rejection_info"), class: "refund-rejection-panel" do
        attributes_table_for refund do
          row(I18n.t("admin.columns.reject_reason")) do
            if reject_log&.metadata&.dig("reason").present?
              reject_log.metadata["reason"]
            else
              span I18n.t("admin.messages.no_reject_reason"), class: "empty"
            end
          end
          row(I18n.t("admin.columns.rejected_at")) do
            reject_log ? l(reject_log.created_at, format: :long) : I18n.t("admin.messages.unknown")
          end
          row(I18n.t("admin.columns.operator")) do
            if reject_log&.actor
              link_to reject_log.actor.email, admin_admin_user_path(reject_log.actor)
            else
              I18n.t("admin.messages.unknown")
            end
          end
        end
      end
    end

    # 审批通过信息面板（仅当已通过时显示）
    if %w[pending succeeded].include?(refund.status)
      approve_log = AuditLog.where(target_type: "Refund", target_id: refund.id, action: "approve")
                            .order(created_at: :desc).first

      if approve_log
        panel I18n.t("admin.panels.refund_approval_info"), class: "refund-approval-panel" do
          attributes_table_for refund do
            row(I18n.t("admin.columns.approved_at")) do
              l(approve_log.created_at, format: :long)
            end
            row(I18n.t("admin.columns.operator")) do
              if approve_log.actor
                link_to approve_log.actor.email, admin_admin_user_path(approve_log.actor)
              else
                I18n.t("admin.messages.unknown")
              end
            end
          end
        end
      end
    end

    # 审计操作日志面板
    panel I18n.t("admin.panels.recent_audit_logs") do
      audit_logs = AuditLog.where(target_type: "Refund", target_id: refund.id)
                           .order(created_at: :desc).limit(10)
      if audit_logs.any?
        table_for audit_logs do
          column(I18n.t("admin.columns.status")) do |log|
            color = case log.action
                    when "approve" then "yes"
                    when "reject"  then "error"
                    else nil
                    end
            status_tag I18n.t("audit_actions.#{log.action}", default: log.action.humanize), class: color
          end
          column(I18n.t("admin.columns.operator")) { |log| log.actor&.email || I18n.t("admin.messages.system") }
          column(I18n.t("admin.columns.reject_reason")) do |log|
            log.metadata&.dig("reason").presence || "-"
          end
          column(I18n.t("admin.columns.ip_address")) { |log| log.ip }
          column(:created_at) { |log| l(log.created_at, format: :long) if log.created_at }
        end
      else
        para I18n.t("admin.messages.no_audit_logs")
      end
    end

    # Provider 请求/響应 payload 面板
    if refund.request_payload.present? || refund.response_payload.present?
      panel "Provider 请求/响应记录" do
        if refund.request_payload.present?
          h4 "请求 Payload (request_payload)"
          pre JSON.pretty_generate(refund.request_payload) rescue refund.request_payload.to_s
        end
        if refund.response_payload.present?
          h4 "响应 Payload (response_payload)"
          pre JSON.pretty_generate(refund.response_payload) rescue refund.response_payload.to_s
        end
      end
    end

    # 回调通知 payload 面板
    if refund.notify_payload.present?
      panel "回调通知记录 (notify_payload)" do
        pre JSON.pretty_generate(refund.notify_payload) rescue refund.notify_payload.to_s
      end
    end

    # 关联工单面板
    related_tickets = Ticket.where(order_id: refund.order_id, category: "payment")
    if related_tickets.any?
      panel "关联退款工单 (#{related_tickets.count})" do
        table_for related_tickets.order(created_at: :desc) do
          column("工单编号") { |t| link_to t.ticket_no, admin_ticket_path(t) }
          column("主题")     { |t| t.subject }
          column("状态") do |t|
            color = case t.status
                    when "closed", "resolved" then "yes"
                    when "in_progress", "assigned" then "warning"
                    else nil
                    end
            status_tag t.status_label, class: color
          end
          column("创建时间") { |t| l(t.created_at, format: :short) if t.created_at }
        end
      end
    end
  end

  # === Member Actions ===

  member_action :approve, method: :put do
    refund = Refund.find(params[:id])
    authorize! :approve, refund

    service = Refunds::ApproveService.new(
      refund:     refund,
      admin_user: current_admin_user,
      request:    request
    ).call

    if service.success?
      redirect_to admin_refund_path(refund),
                  notice: I18n.t("admin.notices.refund_approved")
    else
      redirect_to admin_refund_path(refund),
                  alert: I18n.t("admin.notices.operation_failed", error: service.error)
    end
  end

  member_action :reject, method: [:get, :put] do
    refund = Refund.find(params[:id])
    authorize! :reject, refund

    unless refund.status == "init"
      redirect_to admin_refund_path(refund),
                  alert: I18n.t("admin.alerts.refund_status_not_allow_reject")
      return
    end

    if request.get?
      render inline: <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>#{I18n.t("admin.rejection_form.refund_title")}</title>
          <style>
            body { font-family: sans-serif; padding: 40px; background: #f5f5f5; }
            .container { max-width: 500px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,.1); }
            h2 { margin-top: 0; color: #333; }
            label { display: block; margin-bottom: 8px; font-weight: bold; }
            textarea { width: 100%; height: 120px; padding: 10px; border: 1px solid #ccc; border-radius: 4px; font-size: 14px; box-sizing: border-box; }
            .buttons { margin-top: 20px; }
            button { padding: 10px 20px; font-size: 14px; border-radius: 4px; cursor: pointer; margin-right: 10px; }
            .submit { background: #e74c3c; color: white; border: none; }
            .cancel { background: #95a5a6; color: white; border: none; text-decoration: none; padding: 10px 20px; }
          </style>
        </head>
        <body>
          <div class="container">
            <h2>#{I18n.t("admin.rejection_form.refund_title")}</h2>
            <p>#{I18n.t("admin.rejection_form.refund_id_label")}: <strong>##{refund.id}</strong></p>
            <p>#{I18n.t("admin.columns.amount")}: <strong>¥#{refund.amount}</strong></p>
            <form method="POST" action="#{reject_admin_refund_path(refund)}">
              <input type="hidden" name="_method" value="put">
              <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">
              <label for="reason">#{I18n.t("admin.rejection_form.reason_label")}</label>
              <textarea name="reason" id="reason" required placeholder="#{I18n.t("admin.rejection_form.reason_placeholder")}"></textarea>
              <div class="buttons">
                <button type="submit" class="submit">#{I18n.t("admin.rejection_form.confirm_btn")}</button>
                <a href="#{admin_refund_path(refund)}" class="cancel">#{I18n.t("admin.rejection_form.cancel_btn")}</a>
              </div>
            </form>
          </div>
        </body>
        </html>
      HTML
      return
    end

    # PUT: 处理拒绝操作
    service = Refunds::RejectService.new(
      refund:     refund,
      admin_user: current_admin_user,
      reason:     params[:reason].presence,
      request:    request
    ).call

    if service.success?
      redirect_to admin_refund_path(refund),
                  notice: I18n.t("admin.notices.refund_rejected")
    else
      redirect_to admin_refund_path(refund),
                  alert: I18n.t("admin.notices.operation_failed", error: service.error)
    end
  end

  # Retry failed refund
  member_action :retry_refund, method: :put do
    refund = Refund.find(params[:id])

    service = Refunds::RetryRefundService.new(
      refund:     refund,
      admin_user: current_admin_user,
      request:    request
    ).call

    if service.success?
      redirect_to admin_refund_path(refund), notice: "退款重试已提交，正在处理中..."
    else
      redirect_to admin_refund_path(refund), alert: "重试失败：#{service.error}"
    end
  end

  # === Action Items (show page buttons) ===

  action_item :approve, only: :show,
              if: proc { resource.status == "init" && current_admin_user.admin_can?("refund:approve") } do
    link_to I18n.t("admin.actions.approve_refund"),
            approve_admin_refund_path(resource),
            method: :put,
            data: { confirm: I18n.t("admin.confirmations.approve_refund") },
            class: "action-item-button"
  end

  action_item :reject, only: :show,
              if: proc { resource.status == "init" && current_admin_user.admin_can?("refund:approve") } do
    link_to I18n.t("admin.actions.reject_refund"),
            reject_admin_refund_path(resource),
            class: "action-item-button"
  end

  action_item :retry_refund, only: :show,
              if: proc { resource.status == "failed" } do
    link_to "重试退款", retry_refund_admin_refund_path(resource),
            method: :put,
            data: { confirm: "确定要重试此退款？将重新提交到支付渠道处理。" }
  end

  action_item :create_ticket_from_refund, only: :show,
              if: proc { resource.order.present? } do
    link_to "创建退款工单", create_refund_ticket_admin_order_path(resource.order),
            method: :post,
            data: { confirm: "确定要为此退款关联的订单创建退款工单？" }
  end

  # === CSV Export ===
  csv do
    column :id
    column(I18n.t("admin.columns.order_no")) { |r| r.order&.order_no }
    column :payment_id
    column :amount
    column :reason
    column :status
    column :provider_refund_no
    column :succeeded_at
    column :created_at
  end
end

