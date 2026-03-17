# frozen_string_literal: true

ActiveAdmin.register Settlement do
  menu parent: "settlement_menu", priority: 2, label: proc { I18n.t("admin.labels.settlements") }

  actions :index, :show

  # === Scopes ===
  scope :all, default: true
  scope proc { I18n.t("admin.scopes.pending_review") }, :pending_review do |scope|
    scope.where(status: "pending_review")
  end
  scope proc { I18n.t("admin.scopes.approved") }, :approved do |scope|
    scope.where(status: "approved")
  end
  scope proc { I18n.t("admin.scopes.paid_out") }, :paid_out do |scope|
    scope.where(status: "paid_out")
  end
  scope proc { I18n.t("admin.scopes.confirmed") }, :confirmed do |scope|
    scope.where(status: "confirmed")
  end
  scope proc { I18n.t("admin.scopes.frozen_scope") }, :frozen_scope do |scope|
    scope.where(status: "funds_frozen")
  end
  scope proc { I18n.t("admin.scopes.failed") }, :failed_scope do |scope|
    scope.where(status: "failed")
  end

  # === Filters ===
  filter :settlement_no
  filter :merchant_profile_id
  filter :status, as: :select, collection: -> {
    Settlement.distinct.pluck(:status).compact.map { |s|
      [I18n.t("settlement_statuses.#{s}", default: s.humanize), s]
    }
  }
  filter :net_amount
  filter :period_start
  filter :period_end
  filter :created_at

  # === Index ===
  index do
    selectable_column
    id_column
    column I18n.t("admin.columns.settlement_no"), :settlement_no
    column I18n.t("admin.columns.merchant") do |s|
      link_to s.merchant_name, admin_merchant_profile_path(s.merchant_profile) if s.merchant_profile
    end
    column I18n.t("admin.columns.period") do |s|
      s.period_display
    end
    column I18n.t("admin.columns.total_order_amount") do |s|
      number_to_currency(s.total_order_amount, unit: "¥")
    end
    column I18n.t("admin.columns.total_refund_amount") do |s|
      number_to_currency(s.total_refund_amount, unit: "¥")
    end
    column I18n.t("admin.columns.net_amount") do |s|
      number_to_currency(s.net_amount, unit: "¥")
    end
    column I18n.t("admin.columns.status") do |s|
      status_color = case s.status
                     when "confirmed" then "yes"
                     when "funds_frozen", "failed", "rejected" then "error"
                     when "approved", "paid_out" then "warning"
                     else nil
                     end
      status_tag s.status_label, class: status_color
    end
    column I18n.t("admin.columns.created_time"), :created_at
    actions name: I18n.t("admin.columns.actions"), defaults: false do |s|
      item I18n.t("admin.actions.view"), admin_settlement_path(s)
    end
  end

  # === Show ===
  show title: proc { |s| "结算单 - #{s.settlement_no}" } do
    columns do
      column do
        panel I18n.t("admin.panels.settlement_info") do
          attributes_table_for settlement do
            row(I18n.t("admin.columns.settlement_no")) { |s| s.settlement_no }
            row(I18n.t("admin.columns.merchant")) do |s|
              link_to s.merchant_name, admin_merchant_profile_path(s.merchant_profile) if s.merchant_profile
            end
            row(I18n.t("admin.columns.period")) { |s| s.period_display }
            row(I18n.t("admin.columns.status")) do |s|
              status_color = case s.status
                             when "confirmed" then "yes"
                             when "funds_frozen", "failed", "rejected" then "error"
                             when "approved", "paid_out" then "warning"
                             else nil
                             end
              status_tag s.status_label, class: status_color
            end
          end
        end

        panel I18n.t("admin.panels.settlement_amounts") do
          attributes_table_for settlement do
            row(I18n.t("admin.columns.total_order_amount")) { |s| number_to_currency(s.total_order_amount, unit: "¥") }
            row(I18n.t("admin.columns.total_refund_amount")) { |s| number_to_currency(s.total_refund_amount, unit: "¥") }
            row(I18n.t("admin.columns.deposit_deduction")) { |s| number_to_currency(s.deposit_deduction, unit: "¥") }
            row(I18n.t("admin.columns.penalty_amount")) { |s| number_to_currency(s.penalty_amount, unit: "¥") }
            row(I18n.t("admin.columns.net_amount")) do |s|
              strong { number_to_currency(s.net_amount, unit: "¥") }
            end
          end
        end
      end

      column do
        panel I18n.t("admin.panels.approval_info") do
          attributes_table_for settlement do
            row(I18n.t("admin.columns.approved_by")) { |s| s.approved_by_admin&.email || "-" }
            row(I18n.t("admin.columns.approved_at")) { |s| s.approved_at ? l(s.approved_at, format: :long) : "-" }
            row(I18n.t("admin.columns.paid_out_by")) { |s| s.paid_out_by_admin&.email || "-" }
            row(I18n.t("admin.columns.paid_out_at")) { |s| s.paid_out_at ? l(s.paid_out_at, format: :long) : "-" }
            row(I18n.t("admin.columns.payout_reference")) { |s| s.payout_reference || "-" }
            row(I18n.t("admin.columns.confirmed_at")) { |s| s.confirmed_at ? l(s.confirmed_at, format: :long) : "-" }
            if settlement.failure_reason.present?
              row(I18n.t("admin.columns.failure_reason")) { |s| s.failure_reason }
            end
            if settlement.frozen_reason.present?
              row(I18n.t("admin.columns.frozen_reason")) { |s| s.frozen_reason }
            end
          end
        end
      end
    end

    # === 结算明细 ===
    panel I18n.t("admin.panels.settlement_items") do
      if settlement.settlement_items.any?
        table_for settlement.settlement_items.includes(:order) do
          column("ID") { |item| item.id }
          column(I18n.t("admin.columns.order_no")) do |item|
            link_to item.order.order_no, admin_order_path(item.order) if item.order
          end
          column(I18n.t("admin.columns.order_amount")) { |item| number_to_currency(item.order_amount, unit: "¥") }
          column(I18n.t("admin.columns.refund_amount")) { |item| number_to_currency(item.refund_amount, unit: "¥") }
          column(I18n.t("admin.columns.net_amount")) { |item| number_to_currency(item.net_amount, unit: "¥") }
        end
      else
        para I18n.t("admin.messages.no_settlement_items")
      end
    end

    # === 异常记录 ===
    if settlement.settlement_exceptions.any?
      panel I18n.t("admin.panels.settlement_exceptions") do
        table_for settlement.settlement_exceptions.order(created_at: :desc) do
          column(I18n.t("admin.columns.exception_type")) { |e| e.exception_type_label }
          column(I18n.t("admin.columns.description")) { |e| e.description }
          column(I18n.t("admin.columns.status")) do |e|
            color = case e.status
                    when "resolved" then "yes"
                    when "ignored" then nil
                    else "warning"
                    end
            status_tag e.status_label, class: color
          end
          column(I18n.t("admin.columns.resolved_by")) { |e| e.resolved_by_admin&.email || "-" }
          column(:created_at) { |e| l(e.created_at, format: :short) if e.created_at }
        end
      end
    end

    # === 关联发票 ===
    if settlement.invoices.any?
      panel I18n.t("admin.panels.related_invoices") do
        table_for settlement.invoices.order(created_at: :desc) do
          column(I18n.t("admin.columns.invoice_no")) { |inv| link_to inv.invoice_no, admin_invoice_path(inv) }
          column(I18n.t("admin.columns.amount")) { |inv| number_to_currency(inv.amount, unit: "¥") }
          column(I18n.t("admin.columns.status")) do |inv|
            color = case inv.status
                    when "received" then "yes"
                    when "rejected" then "error"
                    when "shipped" then "warning"
                    else nil
                    end
            status_tag inv.status_label, class: color
          end
        end
      end
    end

    # === 审计日志 ===
    panel I18n.t("admin.panels.recent_audit_logs") do
      audit_logs = AuditLog.where(target_type: "Settlement", target_id: settlement.id)
                           .order(created_at: :desc).limit(10)
      if audit_logs.any?
        table_for audit_logs do
          column(I18n.t("admin.columns.action")) do |log|
            status_tag I18n.t("audit_actions.#{log.action}", default: log.action.humanize)
          end
          column(I18n.t("admin.columns.operator")) { |log| log.actor&.email || I18n.t("admin.messages.system") }
          column(I18n.t("admin.columns.comment")) { |log| log.metadata&.dig("comment").presence || "-" }
          column(I18n.t("admin.columns.ip_address")) { |log| log.ip }
          column(:created_at) { |log| l(log.created_at, format: :long) if log.created_at }
        end
      else
        para I18n.t("admin.messages.no_audit_logs")
      end
    end
  end

  # === Member Actions: 审批 ===
  member_action :approve_settlement, method: [:get, :put] do
    @settlement = Settlement.find(params[:id])

    unless @settlement.may_approve?
      redirect_to admin_settlement_path(@settlement), alert: "当前状态不允许审批"
      return
    end

    if request.get?
      render inline: <<~HTML
        <!DOCTYPE html><html><head><title>审批结算单</title>
        <style>
          body{font-family:sans-serif;padding:40px;background:#f5f5f5}
          .container{max-width:500px;margin:0 auto;background:white;padding:30px;border-radius:8px;box-shadow:0 2px 10px rgba(0,0,0,.1)}
          h2{margin-top:0;color:#333}.info{background:#f0f9ff;border-left:4px solid #3b82f6;padding:12px 16px;margin:16px 0;border-radius:4px}
          label{display:block;margin-bottom:8px;font-weight:bold}
          textarea{width:100%;height:100px;padding:10px;border:1px solid #ccc;border-radius:4px;font-size:14px;box-sizing:border-box}
          .buttons{margin-top:20px}button{padding:10px 20px;font-size:14px;border-radius:4px;cursor:pointer;margin-right:10px}
          .submit{background:#22c55e;color:white;border:none}.cancel{background:#95a5a6;color:white;border:none;text-decoration:none;padding:10px 20px;border-radius:4px}
        </style></head><body><div class="container">
          <h2>✅ 审批结算单</h2>
          <div class="info">
            <p><strong>结算单号：</strong>#{@settlement.settlement_no}</p>
            <p><strong>商家：</strong>#{@settlement.merchant_name}</p>
            <p><strong>结算金额：</strong>¥#{@settlement.net_amount}</p>
            <p><strong>结算周期：</strong>#{@settlement.period_display}</p>
          </div>
          <form method="POST" action="#{approve_settlement_admin_settlement_path(@settlement)}" onsubmit="this.querySelector('.submit').disabled=true;this.querySelector('.submit').innerText='处理中...';">
            <input type="hidden" name="_method" value="put">
            <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">
            <label>审批备注</label>
            <textarea name="comment" placeholder="请填写审批备注"></textarea>
            <div class="buttons">
              <button type="submit" class="submit">确认审批通过</button>
              <a href="#{admin_settlement_path(@settlement)}" class="cancel">取消</a>
            </div>
          </form>
        </div></body></html>
      HTML
      return
    end

    service = Settlements::ApproveService.new(
      settlement: @settlement, admin_user: current_admin_user,
      comment: params[:comment].presence, request: request
    ).call

    if service.success?
      redirect_to admin_settlement_path(@settlement), notice: "结算单已审批通过"
    else
      redirect_to admin_settlement_path(@settlement), alert: "审批失败：#{service.error}"
    end
  end

  # === Member Actions: 拒绝 ===
  member_action :reject_settlement, method: :put do
    settlement = Settlement.find(params[:id])

    unless settlement.may_reject?
      redirect_to admin_settlement_path(settlement), alert: "当前状态不允许拒绝"
      return
    end

    settlement.reject!
    AuditService.log!(action: "reject_settlement", actor: current_admin_user, target: settlement,
                      metadata: { reason: params[:reason] }, request: request)
    redirect_to admin_settlement_path(settlement), notice: "结算单已拒绝"
  end

  # === Member Actions: 打款确认 ===
  member_action :confirm_payout, method: [:get, :put] do
    @settlement = Settlement.find(params[:id])

    unless @settlement.may_payout?
      redirect_to admin_settlement_path(@settlement), alert: "当前状态不允许打款"
      return
    end

    if request.get?
      render inline: <<~HTML
        <!DOCTYPE html><html><head><title>确认打款</title>
        <style>
          body{font-family:sans-serif;padding:40px;background:#f5f5f5}
          .container{max-width:500px;margin:0 auto;background:white;padding:30px;border-radius:8px;box-shadow:0 2px 10px rgba(0,0,0,.1)}
          h2{margin-top:0;color:#333}.info{background:#fef3c7;border-left:4px solid #f59e0b;padding:12px 16px;margin:16px 0;border-radius:4px}
          label{display:block;margin-bottom:8px;font-weight:bold}
          input[type=text],textarea{width:100%;padding:10px;border:1px solid #ccc;border-radius:4px;font-size:14px;box-sizing:border-box;margin-bottom:12px}
          textarea{height:80px}.buttons{margin-top:20px}button{padding:10px 20px;font-size:14px;border-radius:4px;cursor:pointer;margin-right:10px}
          .submit{background:#3b82f6;color:white;border:none}.cancel{background:#95a5a6;color:white;border:none;text-decoration:none;padding:10px 20px;border-radius:4px}
        </style></head><body><div class="container">
          <h2>💰 确认打款</h2>
          <div class="info">
            <p><strong>结算单号：</strong>#{@settlement.settlement_no}</p>
            <p><strong>商家：</strong>#{@settlement.merchant_name}</p>
            <p><strong>打款金额：</strong>¥#{@settlement.net_amount}</p>
          </div>
          <form method="POST" action="#{confirm_payout_admin_settlement_path(@settlement)}" onsubmit="this.querySelector('.submit').disabled=true;this.querySelector('.submit').innerText='处理中...';">
            <input type="hidden" name="_method" value="put">
            <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">
            <label>打款凭证号 <span style="color:red">*</span></label>
            <input type="text" name="payout_reference" required placeholder="请输入银行转账凭证号">
            <label>备注</label>
            <textarea name="comment" placeholder="打款备注（选填）"></textarea>
            <div class="buttons">
              <button type="submit" class="submit">确认已打款</button>
              <a href="#{admin_settlement_path(@settlement)}" class="cancel">取消</a>
            </div>
          </form>
        </div></body></html>
      HTML
      return
    end

    service = Settlements::ConfirmPayoutService.new(
      settlement: @settlement, admin_user: current_admin_user,
      payout_reference: params[:payout_reference],
      comment: params[:comment].presence, request: request
    ).call

    if service.success?
      redirect_to admin_settlement_path(@settlement), notice: "打款已确认"
    else
      redirect_to admin_settlement_path(@settlement), alert: "打款失败：#{service.error}"
    end
  end

  # === Member Actions: 到账确认 ===
  member_action :confirm_arrival, method: :put do
    settlement = Settlement.find(params[:id])
    service = Settlements::ConfirmArrivalService.new(
      settlement: settlement, admin_user: current_admin_user,
      comment: params[:comment].presence, request: request
    ).call

    if service.success?
      redirect_to admin_settlement_path(settlement), notice: "已确认到账"
    else
      redirect_to admin_settlement_path(settlement), alert: "操作失败：#{service.error}"
    end
  end

  # === Member Actions: 冻结 ===
  member_action :freeze_settlement, method: [:get, :put] do
    @settlement = Settlement.find(params[:id])

    unless @settlement.may_freeze_settlement?
      redirect_to admin_settlement_path(@settlement), alert: "当前状态不允许冻结"
      return
    end

    if request.get?
      render inline: <<~HTML
        <!DOCTYPE html><html><head><title>冻结结算</title>
        <style>
          body{font-family:sans-serif;padding:40px;background:#f5f5f5}
          .container{max-width:500px;margin:0 auto;background:white;padding:30px;border-radius:8px;box-shadow:0 2px 10px rgba(0,0,0,.1)}
          h2{margin-top:0;color:#e74c3c}.warning{background:#fef2f2;border-left:4px solid #ef4444;padding:12px 16px;margin:16px 0;border-radius:4px}
          label{display:block;margin-bottom:8px;font-weight:bold}
          textarea{width:100%;height:120px;padding:10px;border:1px solid #ccc;border-radius:4px;font-size:14px;box-sizing:border-box}
          .buttons{margin-top:20px}button{padding:10px 20px;font-size:14px;border-radius:4px;cursor:pointer;margin-right:10px}
          .submit{background:#e74c3c;color:white;border:none}.cancel{background:#95a5a6;color:white;border:none;text-decoration:none;padding:10px 20px;border-radius:4px}
        </style></head><body><div class="container">
          <h2>🔒 冻结结算资金</h2>
          <div class="warning">
            <p><strong>结算单号：</strong>#{@settlement.settlement_no}</p>
            <p><strong>金额：</strong>¥#{@settlement.net_amount}</p>
            <p>冻结后将暂停该结算单的后续流程，需手动解冻或重试。</p>
          </div>
          <form method="POST" action="#{freeze_settlement_admin_settlement_path(@settlement)}" onsubmit="this.querySelector('.submit').disabled=true;this.querySelector('.submit').innerText='处理中...';">
            <input type="hidden" name="_method" value="put">
            <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">
            <label>冻结原因 <span style="color:red">*</span></label>
            <textarea name="reason" required placeholder="请说明冻结原因"></textarea>
            <div class="buttons">
              <button type="submit" class="submit">确认冻结</button>
              <a href="#{admin_settlement_path(@settlement)}" class="cancel">取消</a>
            </div>
          </form>
        </div></body></html>
      HTML
      return
    end

    service = Settlements::FreezeService.new(
      settlement: @settlement, admin_user: current_admin_user,
      reason: params[:reason], request: request
    ).call

    if service.success?
      redirect_to admin_settlement_path(@settlement), notice: "结算已冻结"
    else
      redirect_to admin_settlement_path(@settlement), alert: "冻结失败：#{service.error}"
    end
  end

  # === Member Actions: 重试 ===
  member_action :retry_settlement, method: :put do
    settlement = Settlement.find(params[:id])
    service = Settlements::RetryService.new(
      settlement: settlement, admin_user: current_admin_user,
      comment: params[:comment].presence, request: request
    ).call

    if service.success?
      redirect_to admin_settlement_path(settlement), notice: "结算单已重新提交审核"
    else
      redirect_to admin_settlement_path(settlement), alert: "重试失败：#{service.error}"
    end
  end

  # === Member Actions: 手动触发生成 ===
  action_item :generate_settlements, only: :index,
              if: proc { current_admin_user.admin_can?("settlement:manage") } do
    link_to "手动生成结算单", trigger_generate_admin_settlements_path, method: :post,
            data: { confirm: "确定要手动触发结算单生成？将对昨日已完成订单生成结算单。" }
  end

  collection_action :trigger_generate, method: :post do
    Settlements::GenerateJob.perform_later
    redirect_to admin_settlements_path, notice: "结算单生成任务已提交，请稍后刷新查看"
  end

  # === Action Items ===
  action_item :approve, only: :show,
              if: proc { resource.may_approve? && current_admin_user.admin_can?("settlement:approve") } do
    link_to "审批通过", approve_settlement_admin_settlement_path(resource)
  end

  action_item :reject, only: :show,
              if: proc { resource.may_reject? && current_admin_user.admin_can?("settlement:approve") } do
    link_to "拒绝", reject_settlement_admin_settlement_path(resource), method: :put,
            data: { confirm: "确定要拒绝此结算单？" }
  end

  action_item :payout, only: :show,
              if: proc { resource.may_payout? && current_admin_user.admin_can?("settlement:payout") } do
    link_to "确认打款", confirm_payout_admin_settlement_path(resource)
  end

  action_item :confirm_arrival, only: :show,
              if: proc { resource.may_confirm_arrival? && current_admin_user.admin_can?("settlement:payout") } do
    link_to "确认到账", confirm_arrival_admin_settlement_path(resource), method: :put,
            data: { confirm: "确定商家已收到款项？" }
  end

  action_item :freeze, only: :show,
              if: proc { resource.may_freeze_settlement? && current_admin_user.admin_can?("settlement:manage") } do
    link_to "冻结资金", freeze_settlement_admin_settlement_path(resource)
  end

  action_item :retry, only: :show,
              if: proc { resource.may_retry_settlement? && current_admin_user.admin_can?("settlement:manage") } do
    link_to "重试", retry_settlement_admin_settlement_path(resource), method: :put,
            data: { confirm: "确定要重试此结算单？将重新提交审核。" }
  end

  # === CSV Export ===
  csv do
    column :id
    column :settlement_no
    column(I18n.t("admin.columns.merchant")) { |s| s.merchant_name }
    column :period_start
    column :period_end
    column :total_order_amount
    column :total_refund_amount
    column :deposit_deduction
    column :penalty_amount
    column :net_amount
    column :status
    column :approved_at
    column :paid_out_at
    column :confirmed_at
    column :payout_reference
    column :created_at
  end
end
