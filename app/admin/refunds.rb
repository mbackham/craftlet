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
             approve_admin_refund_path(refund)
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

    # 拒绝信息面板与系统失败原因（仅当退款为 failed 时显示）
    if refund.status == "failed"
      reject_log = AuditLog.where(target_type: "Refund", target_id: refund.id, action: "reject")
                           .order(created_at: :desc).first

      panel I18n.t("admin.panels.refund_rejection_info", default: "异常与拒绝信息"), class: "refund-rejection-panel" do
        attributes_table_for refund do
          if refund.failure_reason.present?
            row(I18n.t("admin.columns.failure_reason", default: "系统失败原因")) { |r| r.failure_reason }
            row(I18n.t("admin.columns.failed_at", default: "失败时间")) { |r| l(r.updated_at, format: :long) }
            row(I18n.t("admin.columns.third_party_error_code", default: "第三方响应代码")) do |r|
              r.response_payload&.dig('error_code') || r.response_payload&.dig('sub_code') || "-"
            end
          end

          row(I18n.t("admin.columns.reject_reason", default: "人工拒绝原因")) do
            if reject_log&.metadata&.dig("reason").present?
              reject_log.metadata["reason"]
            else
              span I18n.t("admin.messages.no_reject_reason"), class: "empty"
            end
          end
          row(I18n.t("admin.columns.rejected_at", default: "人工审核时间")) do
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
          column("操作备注") do |log|
            log.metadata&.dig("comment").presence || "-"
          end
          column(I18n.t("admin.columns.ip_address")) { |log| log.ip }
          column(:created_at) { |log| l(log.created_at, format: :long) if log.created_at }
        end
      else
        para I18n.t("admin.messages.no_audit_logs")
      end
    end

    # Provider 请求/响应与回调通知 payload 面板
    if current_admin_user.admin_can?("refund:approve")
      if refund.request_payload.present? || refund.response_payload.present? || refund.notify_payload.present?
        panel "底层数据载荷（仅高权限可见）" do
          if refund.request_payload.present?
            h4 "请求 Payload (request_payload)"
            pre JSON.pretty_generate(refund.request_payload) rescue refund.request_payload.to_s
          end
          if refund.response_payload.present?
            h4 "响应 Payload (response_payload)"
            pre JSON.pretty_generate(refund.response_payload) rescue refund.response_payload.to_s
          end
          if refund.notify_payload.present?
            h4 "回调通知记录 (notify_payload)"
            pre JSON.pretty_generate(refund.notify_payload) rescue refund.notify_payload.to_s
          end
        end
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

  member_action :approve, method: [:get, :put] do
    refund = Refund.find(params[:id])
    authorize! :approve, refund

    unless refund.status == "init"
      redirect_to admin_refund_path(refund),
                  alert: I18n.t("admin.alerts.refund_status_not_allow_reject", default: "当前状态不允许审批")
      return
    end

    if request.get?
      render inline: <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>确认审批退款</title>
          <style>
            body { font-family: sans-serif; padding: 40px; background: #f5f5f5; }
            .container { max-width: 500px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,.1); }
            h2 { margin-top: 0; color: #333; }
            .info { background: #f0f9ff; border-left: 4px solid #3b82f6; padding: 12px 16px; margin: 16px 0; border-radius: 4px; }
            .warning { background: #fef3c7; border-left: 4px solid #f59e0b; padding: 12px 16px; margin: 16px 0; border-radius: 4px; font-size: 13px; }
            label { display: block; margin-bottom: 8px; font-weight: bold; }
            textarea { width: 100%; height: 100px; padding: 10px; border: 1px solid #ccc; border-radius: 4px; font-size: 14px; box-sizing: border-box; }
            .buttons { margin-top: 20px; }
            button { padding: 10px 20px; font-size: 14px; border-radius: 4px; cursor: pointer; margin-right: 10px; }
            .submit { background: #22c55e; color: white; border: none; }
            .submit:hover { background: #16a34a; }
            .cancel { background: #95a5a6; color: white; border: none; text-decoration: none; padding: 10px 20px; border-radius: 4px; }
          </style>
        </head>
        <body>
          <div class="container">
            <h2>⚠️ 确认审批通过退款</h2>
            <div class="info">
              <p><strong>退款编号：</strong>##{refund.id}</p>
              <p><strong>关联订单：</strong>#{refund.order&.order_no}</p>
              <p><strong>退款金额：</strong>¥#{refund.amount}</p>
              <p><strong>退款原因：</strong>#{refund.reason}</p>
            </div>
            <div class="warning">
              审批通过后，系统将立即向支付渠道发起退款请求，此操作不可撤销。
            </div>
            <form method="POST" action="#{approve_admin_refund_path(refund)}">
              <input type="hidden" name="_method" value="put">
              <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">
              <label for="comment">操作备注 <span style="color:#999;font-weight:normal">(必填)</span></label>
              <textarea name="comment" id="comment" required placeholder="请填写审批备注，例如：经核实退款理由合理，予以通过"></textarea>
              <div class="buttons">
                <button type="submit" class="submit">确认审批通过</button>
                <a href="#{admin_refund_path(refund)}" class="cancel">取消</a>
              </div>
            </form>
          </div>
        </body>
        </html>
      HTML
      return
    end

    # PUT: 执行审批
    service = Refunds::ApproveService.new(
      refund:     refund,
      admin_user: current_admin_user,
      comment:    params[:comment].presence,
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
  member_action :retry_refund, method: [:get, :put] do
    refund = Refund.find(params[:id])

    unless refund.status == "failed"
      redirect_to admin_refund_path(refund), alert: "当前状态不允许重试"
      return
    end

    if request.get?
      render inline: <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>确认重试退款</title>
          <style>
            body { font-family: sans-serif; padding: 40px; background: #f5f5f5; }
            .container { max-width: 500px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,.1); }
            h2 { margin-top: 0; color: #333; }
            .info { background: #fef2f2; border-left: 4px solid #ef4444; padding: 12px 16px; margin: 16px 0; border-radius: 4px; }
            .warning { background: #fef3c7; border-left: 4px solid #f59e0b; padding: 12px 16px; margin: 16px 0; border-radius: 4px; font-size: 13px; }
            label { display: block; margin-bottom: 8px; font-weight: bold; }
            textarea { width: 100%; height: 100px; padding: 10px; border: 1px solid #ccc; border-radius: 4px; font-size: 14px; box-sizing: border-box; }
            .buttons { margin-top: 20px; }
            button { padding: 10px 20px; font-size: 14px; border-radius: 4px; cursor: pointer; margin-right: 10px; }
            .submit { background: #f59e0b; color: white; border: none; }
            .submit:hover { background: #d97706; }
            .cancel { background: #95a5a6; color: white; border: none; text-decoration: none; padding: 10px 20px; border-radius: 4px; }
          </style>
        </head>
        <body>
          <div class="container">
            <h2>⚠️ 确认重试退款</h2>
            <div class="info">
              <p><strong>退款编号：</strong>##{refund.id}</p>
              <p><strong>退款金额：</strong>¥#{refund.amount}</p>
              <p><strong>失败原因：</strong>#{refund.failure_reason || '未知'}</p>
            </div>
            <div class="warning">
              重试将重新向支付渠道发起退款请求。请确认已排查失败原因后再操作。
            </div>
            <form method="POST" action="#{retry_refund_admin_refund_path(refund)}">
              <input type="hidden" name="_method" value="put">
              <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">
              <label for="comment">操作备注 <span style="color:#999;font-weight:normal">(必填)</span></label>
              <textarea name="comment" id="comment" required placeholder="请填写重试原因，例如：网络超时已恢复，重新发起退款"></textarea>
              <div class="buttons">
                <button type="submit" class="submit">确认重试</button>
                <a href="#{admin_refund_path(refund)}" class="cancel">取消</a>
              </div>
            </form>
          </div>
        </body>
        </html>
      HTML
      return
    end

    # PUT: 执行重试
    service = Refunds::RetryRefundService.new(
      refund:     refund,
      admin_user: current_admin_user,
      comment:    params[:comment].presence,
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
            class: "action-item-button"
  end

  action_item :reject, only: :show,
              if: proc { resource.status == "init" && current_admin_user.admin_can?("refund:approve") } do
    link_to I18n.t("admin.actions.reject_refund"),
            reject_admin_refund_path(resource),
            class: "action-item-button"
  end

  action_item :retry_refund, only: :show,
              if: proc { resource.status == "failed" && current_admin_user.admin_can?("refund:approve") } do
    link_to "重试退款", retry_refund_admin_refund_path(resource)
  end

  action_item :create_ticket_from_refund, only: :show,
              if: proc { resource.order.present? && current_admin_user.admin_can?("ticket:manage") } do
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

