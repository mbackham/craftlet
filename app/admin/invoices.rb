# frozen_string_literal: true

ActiveAdmin.register Invoice do
  menu parent: "settlement_menu", priority: 3, label: proc { I18n.t("admin.labels.invoices") }

  actions :index, :show, :new, :create

  permit_params :settlement_id, :merchant_profile_id, :invoice_type, :amount, :title, :tax_no

  # === Scopes ===
  scope :all, default: true
  scope proc { I18n.t("admin.scopes.pending_issue") }, :pending_issue do |scope|
    scope.where(status: "requested")
  end
  scope proc { I18n.t("admin.scopes.issued") }, :issued do |scope|
    scope.where(status: "issued")
  end
  scope proc { I18n.t("admin.scopes.shipped") }, :shipped do |scope|
    scope.where(status: "shipped")
  end
  scope proc { I18n.t("admin.scopes.received") }, :received do |scope|
    scope.where(status: "received")
  end

  # === Filters ===
  filter :invoice_no
  filter :merchant_profile_id
  filter :status, as: :select, collection: -> {
    %w[requested issued shipped received rejected].map { |s|
      [I18n.t("invoice_statuses.#{s}", default: s.humanize), s]
    }
  }
  filter :amount
  filter :tracking_no
  filter :created_at

  # === Index ===
  index do
    selectable_column
    id_column
    column I18n.t("admin.columns.invoice_no"), :invoice_no
    column I18n.t("admin.columns.merchant") do |inv|
      inv.merchant_name
    end
    column I18n.t("admin.columns.settlement_no") do |inv|
      link_to inv.settlement.settlement_no, admin_settlement_path(inv.settlement) if inv.settlement
    end
    column I18n.t("admin.columns.invoice_type") do |inv|
      inv.invoice_type_label
    end
    column I18n.t("admin.columns.amount") do |inv|
      number_to_currency(inv.amount, unit: "¥")
    end
    column I18n.t("admin.columns.status") do |inv|
      color = case inv.status
              when "received" then "yes"
              when "rejected" then "error"
              when "shipped" then "warning"
              else nil
              end
      status_tag inv.status_label, class: color
    end
    column I18n.t("admin.columns.tracking_no"), :tracking_no
    column I18n.t("admin.columns.created_time"), :created_at
    actions name: I18n.t("admin.columns.actions"), defaults: false do |inv|
      item I18n.t("admin.actions.view"), admin_invoice_path(inv)
    end
  end

  # === Show ===
  show title: proc { |inv| "发票 - #{inv.invoice_no}" } do
    attributes_table do
      row(:id)
      row(I18n.t("admin.columns.invoice_no")) { |inv| inv.invoice_no }
      row(I18n.t("admin.columns.settlement_no")) do |inv|
        link_to inv.settlement.settlement_no, admin_settlement_path(inv.settlement) if inv.settlement
      end
      row(I18n.t("admin.columns.merchant")) { |inv| inv.merchant_name }
      row(I18n.t("admin.columns.invoice_type")) { |inv| inv.invoice_type_label }
      row(I18n.t("admin.columns.amount")) { |inv| number_to_currency(inv.amount, unit: "¥") }
      row(I18n.t("admin.columns.title")) { |inv| inv.title || "-" }
      row(I18n.t("admin.columns.tax_no")) { |inv| inv.tax_no || "-" }
      row(I18n.t("admin.columns.status")) do |inv|
        color = case inv.status
                when "received" then "yes"
                when "rejected" then "error"
                when "shipped" then "warning"
                else nil
                end
        status_tag inv.status_label, class: color
      end
      row(I18n.t("admin.columns.tracking_no")) { |inv| inv.tracking_no || "-" }
      row(I18n.t("admin.columns.issued_by")) { |inv| inv.issued_by_admin&.email || "-" }
      row(I18n.t("admin.columns.issued_at")) { |inv| inv.issued_at ? l(inv.issued_at, format: :long) : "-" }
      row(I18n.t("admin.columns.shipped_at")) { |inv| inv.shipped_at ? l(inv.shipped_at, format: :long) : "-" }
      row(I18n.t("admin.columns.received_at")) { |inv| inv.received_at ? l(inv.received_at, format: :long) : "-" }
      if invoice.rejected_reason.present?
        row(I18n.t("admin.columns.rejected_reason")) { |inv| inv.rejected_reason }
      end
      row(:requested_at) { |inv| inv.requested_at ? l(inv.requested_at, format: :long) : "-" }
      row(:created_at) { |inv| l(inv.created_at, format: :long) if inv.created_at }
    end
  end

  # === Form ===
  form do |f|
    f.inputs I18n.t("admin.panels.invoice_request") do
      f.input :settlement_id, as: :select,
              collection: Settlement.where(status: "confirmed").map { |s| ["#{s.settlement_no} (¥#{s.net_amount})", s.id] },
              include_blank: "请选择结算单"
      f.input :merchant_profile_id, as: :select,
              collection: MerchantProfile.approved.map { |m| ["#{m.shop_name} (ID:#{m.id})", m.id] }
      f.input :invoice_type, as: :select, collection: [
        [I18n.t("invoice_types.normal", default: "普通发票"), "normal"],
        [I18n.t("invoice_types.special", default: "专用发票"), "special"]
      ]
      f.input :amount
      f.input :title, hint: "发票抬头"
      f.input :tax_no, hint: "纳税人识别号"
    end
    f.actions
  end

  # === Member Actions ===

  # 开具发票
  member_action :issue_invoice, method: :put do
    invoice = Invoice.find(params[:id])
    unless invoice.may_issue?
      redirect_to admin_invoice_path(invoice), alert: "当前状态不允许开具"
      return
    end

    invoice.issued_by = current_admin_user.id
    invoice.issued_at = Time.current
    invoice.issue!

    AuditService.log!(action: "issue_invoice", actor: current_admin_user, target: invoice, request: request)
    redirect_to admin_invoice_path(invoice), notice: "发票已开具"
  end

  # 寄送发票
  member_action :ship_invoice, method: [:get, :put] do
    @invoice = Invoice.find(params[:id])

    unless @invoice.may_ship?
      redirect_to admin_invoice_path(@invoice), alert: "当前状态不允许寄送"
      return
    end

    if request.get?
      render inline: <<~HTML
        <!DOCTYPE html><html><head><title>寄送发票</title>
        <style>
          body{font-family:sans-serif;padding:40px;background:#f5f5f5}
          .container{max-width:400px;margin:0 auto;background:white;padding:30px;border-radius:8px;box-shadow:0 2px 10px rgba(0,0,0,.1)}
          h2{margin-top:0;color:#333}label{display:block;margin-bottom:8px;font-weight:bold}
          input[type=text]{width:100%;padding:10px;border:1px solid #ccc;border-radius:4px;font-size:14px;box-sizing:border-box}
          .buttons{margin-top:20px}button{padding:10px 20px;font-size:14px;border-radius:4px;cursor:pointer;margin-right:10px}
          .submit{background:#3b82f6;color:white;border:none}.cancel{background:#95a5a6;color:white;border:none;text-decoration:none;padding:10px 20px;border-radius:4px}
        </style></head><body><div class="container">
          <h2>📦 寄送发票</h2>
          <p>发票编号: <strong>#{@invoice.invoice_no}</strong></p>
          <form method="POST" action="#{ship_invoice_admin_invoice_path(@invoice)}" onsubmit="this.querySelector('.submit').disabled=true">
            <input type="hidden" name="_method" value="put">
            <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">
            <label>快递单号 <span style="color:red">*</span></label>
            <input type="text" name="tracking_no" required placeholder="请输入快递单号">
            <div class="buttons">
              <button type="submit" class="submit">确认寄送</button>
              <a href="#{admin_invoice_path(@invoice)}" class="cancel">取消</a>
            </div>
          </form>
        </div></body></html>
      HTML
      return
    end

    @invoice.tracking_no = params[:tracking_no]
    @invoice.shipped_at = Time.current
    @invoice.ship!

    AuditService.log!(action: "ship_invoice", actor: current_admin_user, target: @invoice,
                      metadata: { tracking_no: params[:tracking_no] }, request: request)
    redirect_to admin_invoice_path(@invoice), notice: "发票已寄送，快递单号: #{params[:tracking_no]}"
  end

  # 签收确认
  member_action :receive_invoice, method: :put do
    invoice = Invoice.find(params[:id])
    unless invoice.may_receive?
      redirect_to admin_invoice_path(invoice), alert: "当前状态不允许签收"
      return
    end

    invoice.received_at = Time.current
    invoice.receive!

    AuditService.log!(action: "receive_invoice", actor: current_admin_user, target: invoice, request: request)
    redirect_to admin_invoice_path(invoice), notice: "发票已确认签收"
  end

  # 驳回发票
  member_action :reject_invoice, method: :put do
    invoice = Invoice.find(params[:id])
    unless invoice.may_reject_invoice?
      redirect_to admin_invoice_path(invoice), alert: "当前状态不允许驳回"
      return
    end

    invoice.rejected_reason = params[:reason].presence || "未说明原因"
    invoice.reject_invoice!

    AuditService.log!(action: "reject_invoice", actor: current_admin_user, target: invoice,
                      metadata: { reason: invoice.rejected_reason }, request: request)
    redirect_to admin_invoice_path(invoice), notice: "发票申请已驳回"
  end

  # === Action Items ===
  action_item :issue, only: :show,
              if: proc { resource.may_issue? && current_admin_user.admin_can?("settlement:manage") } do
    link_to "开具发票", issue_invoice_admin_invoice_path(resource), method: :put,
            data: { confirm: "确定开具此发票？" }
  end

  action_item :ship, only: :show,
              if: proc { resource.may_ship? && current_admin_user.admin_can?("settlement:manage") } do
    link_to "寄送发票", ship_invoice_admin_invoice_path(resource)
  end

  action_item :receive, only: :show,
              if: proc { resource.may_receive? && current_admin_user.admin_can?("settlement:manage") } do
    link_to "确认签收", receive_invoice_admin_invoice_path(resource), method: :put,
            data: { confirm: "确定已签收？" }
  end

  action_item :reject, only: :show,
              if: proc { resource.may_reject_invoice? && current_admin_user.admin_can?("settlement:manage") } do
    link_to "驳回", reject_invoice_admin_invoice_path(resource), method: :put,
            data: { confirm: "确定驳回此发票申请？" }
  end

  # === CSV Export ===
  csv do
    column :id
    column :invoice_no
    column(I18n.t("admin.columns.merchant")) { |inv| inv.merchant_name }
    column(I18n.t("admin.columns.settlement_no")) { |inv| inv.settlement&.settlement_no }
    column :invoice_type
    column :amount
    column :title
    column :tax_no
    column :status
    column :tracking_no
    column :issued_at
    column :shipped_at
    column :received_at
    column :created_at
  end
end
