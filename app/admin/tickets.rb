# frozen_string_literal: true

ActiveAdmin.register Ticket do
  menu parent: "orders_menu", priority: 5, label: proc { "工单管理" }

  permit_params :subject, :description, :category, :priority

  # === Scopes ===
  scope :all, default: true
  scope("待处理") { |s| s.where(status: %w[open assigned]) }
  scope("处理中") { |s| s.where(status: "in_progress") }
  scope("已解决") { |s| s.where(status: "resolved") }
  scope("已关闭") { |s| s.where(status: "closed") }
  scope("紧急")   { |s| s.where(priority: "urgent") }

  # === Filters ===
  filter :ticket_no
  filter :subject
  filter :status, as: :select, collection: -> {
    %w[open assigned in_progress resolved closed].map { |s| [I18n.t("ticket_statuses.#{s}", default: s.humanize), s] }
  }
  filter :category, as: :select, collection: -> {
    Ticket::CATEGORIES.map { |c| [I18n.t("ticket_categories.#{c}", default: c.humanize), c] }
  }
  filter :priority, as: :select, collection: -> {
    Ticket::PRIORITIES.map { |p| [I18n.t("ticket_priorities.#{p}", default: p.humanize), p] }
  }
  filter :created_at

  # === Index ===
  index do
    selectable_column
    id_column
    column("工单编号", :ticket_no)
    column("主题", :subject)
    column("分类") { |t| status_tag t.category_label }
    column("优先级") do |t|
      color = case t.priority
              when "urgent" then "error"
              when "high"   then "warning"
              when "normal" then nil
              when "low"    then "yes"
              end
      status_tag t.priority_label, class: color
    end
    column("状态") do |t|
      color = case t.status
              when "closed"      then "yes"
              when "resolved"    then "yes"
              when "in_progress" then "warning"
              when "assigned"    then "warning"
              else nil
              end
      status_tag t.status_label, class: color
    end
    column("创建人") { |t| t.creator&.email || t.creator_id }
    column("处理人") { |t| t.assignee&.email || "-" }
    column("回复数") { |t| t.messages.count }
    column("创建时间", :created_at)
    actions name: "操作", defaults: false do |ticket|
      item "查看", admin_ticket_path(ticket)
    end
  end

  # === Show ===
  show title: proc { |t| "工单 ##{t.ticket_no}" } do
    columns do
      column span: 2 do
        panel "工单信息" do
          attributes_table_for ticket do
            row("工单编号") { |t| t.ticket_no }
            row("主题")     { |t| t.subject }
            row("描述")     { |t| simple_format(t.description) if t.description.present? }
            row("分类")     { |t| status_tag t.category_label }
            row("优先级") do |t|
              color = case t.priority
                      when "urgent" then "error"
                      when "high"   then "warning"
                      else nil
                      end
              status_tag t.priority_label, class: color
            end
            row("状态") do |t|
              color = case t.status
                      when "closed", "resolved" then "yes"
                      when "in_progress", "assigned" then "warning"
                      else nil
                      end
              status_tag t.status_label, class: color
            end
            row("创建人")   { |t| t.creator&.email || t.creator_id }
            row("处理人")   { |t| t.assignee&.email || "-" }
            row("创建时间") { |t| l(t.created_at, format: :long) if t.created_at }
            row("指派时间") { |t| l(t.assigned_at, format: :long) if t.assigned_at }
            row("解决时间") { |t| l(t.resolved_at, format: :long) if t.resolved_at }
            row("关闭时间") { |t| l(t.closed_at, format: :long) if t.closed_at }
          end
        end

        # Messages / replies
        panel "沟通记录 (#{ticket.messages.count})" do
          if ticket.messages.any?
            ticket.messages.order(created_at: :asc).each do |msg|
              div class: "ticket-message #{msg.internal? ? 'internal-note' : ''}" do
                div class: "message-header" do
                  strong msg.sender_display
                  span " — #{l(msg.created_at, format: :long)}", style: "color: #999;"
                  if msg.internal?
                    status_tag "内部备注", class: "warning"
                  end
                end
                div class: "message-body" do
                  simple_format msg.content
                end
                if msg.attachments.any?
                  div class: "message-attachments" do
                    msg.attachments.each do |att|
                      div do
                        if att.url.present?
                          link_to "📎 #{att.file_name} (#{att.file_size_display})", att.url, target: "_blank"
                        else
                          span "📎 #{att.file_name} (#{att.file_size_display}) — OSS: #{att.oss_key}"
                        end
                      end
                    end
                  end
                end
              end
              hr
            end
          else
            para "暂无沟通记录"
          end
        end
      end

      column do
        # Related order
        if ticket.order_id.present?
          panel "关联订单" do
            order = ticket.related_order
            if order
              attributes_table_for order do
                row("订单号") { link_to order.order_no, admin_order_path(order) }
                row("状态")   { status_tag order.status_label }
                row("金额")   { number_to_currency(order.total_amount, unit: "¥") }
              end
            else
              para "订单未找到 (#{ticket.order_id})"
            end
          end
        end
      end
    end
  end

  # === New Ticket Form ===
  form title: "创建工单" do |f|
    f.inputs "工单信息" do
      f.input :subject, label: "主题"
      f.input :description, as: :text, label: "描述"
      f.input :category, as: :select, label: "分类",
              collection: Ticket::CATEGORIES.map { |c| [I18n.t("ticket_categories.#{c}", default: c.humanize), c] },
              include_blank: false
      f.input :priority, as: :select, label: "优先级",
              collection: Ticket::PRIORITIES.map { |p| [I18n.t("ticket_priorities.#{p}", default: p.humanize), p] },
              include_blank: false
    end
    f.actions
  end

  controller do
    def create
      @ticket = Ticket.new(permitted_params[:ticket])
      # Set creator to current admin
      @ticket.creator_id = AuditService.format_as_uuid(current_admin_user.id)
      @ticket.creator_type = "AdminUser"

      if @ticket.save
        AuditService.log!(
          action:  "ticket_create",
          actor:   current_admin_user,
          target:  @ticket,
          after:   @ticket.attributes,
          request: request
        )
        redirect_to admin_ticket_path(@ticket), notice: "工单创建成功"
      else
        render :new
      end
    end
  end

  # === Action Items (Buttons) ===
  action_item :assign, only: :show, if: proc { resource.may_assign? } do
    link_to "指派处理人", assign_admin_ticket_path(resource)
  end

  action_item :start_work, only: :show, if: proc { resource.may_start_work? } do
    link_to "开始处理", start_work_admin_ticket_path(resource), method: :put,
            data: { confirm: "确定开始处理此工单？" }
  end

  action_item :resolve, only: :show, if: proc { resource.may_resolve? } do
    link_to "标记解决", resolve_admin_ticket_path(resource), method: :put,
            data: { confirm: "确定标记此工单为已解决？" }
  end

  action_item :close, only: :show, if: proc { resource.may_close? } do
    link_to "关闭工单", close_ticket_admin_ticket_path(resource), method: :put,
            data: { confirm: "确定关闭此工单？" }
  end

  action_item :reopen, only: :show, if: proc { resource.may_reopen? } do
    link_to "重新打开", reopen_admin_ticket_path(resource), method: :put,
            data: { confirm: "确定重新打开此工单？" }
  end

  action_item :reply, only: :show, if: proc { !resource.closed? } do
    link_to "回复", reply_admin_ticket_path(resource)
  end

  # === Member Actions ===

  # Assign handler
  member_action :assign, method: [:get, :put] do
    @ticket = Ticket.find(params[:id])

    if request.get?
      @admins = AdminUser.order(:email)
      render "admin/tickets/assign"
    elsif request.put?
      admin = AdminUser.find(params[:assignee_id])
      assignee_uuid = AuditService.format_as_uuid(admin.id)

      @ticket.assignee_id = assignee_uuid
      @ticket.assigned_at = Time.current
      @ticket.assign! if @ticket.may_assign?
      @ticket.save!

      AuditService.log!(
        action:  "ticket_assign",
        actor:   current_admin_user,
        target:  @ticket,
        after:   { assignee_id: assignee_uuid, assignee_email: admin.email },
        request: request
      )

      redirect_to admin_ticket_path(@ticket), notice: "工单已指派给 #{admin.email}"
    end
  end

  # Start work
  member_action :start_work, method: :put do
    ticket = Ticket.find(params[:id])
    ticket.start_work!

    AuditService.log!(
      action: "ticket_start_work", actor: current_admin_user, target: ticket,
      after: { status: "in_progress" }, request: request
    )

    redirect_to admin_ticket_path(ticket), notice: "工单已开始处理"
  end

  # Resolve
  member_action :resolve, method: :put do
    ticket = Ticket.find(params[:id])
    ticket.resolved_at = Time.current
    ticket.resolve!

    AuditService.log!(
      action: "ticket_resolve", actor: current_admin_user, target: ticket,
      after: { status: "resolved" }, request: request
    )

    redirect_to admin_ticket_path(ticket), notice: "工单已标记为解决"
  end

  # Close
  member_action :close_ticket, method: :put do
    ticket = Ticket.find(params[:id])
    ticket.closed_at = Time.current
    ticket.close!

    AuditService.log!(
      action: "ticket_close", actor: current_admin_user, target: ticket,
      after: { status: "closed" }, request: request
    )

    redirect_to admin_ticket_path(ticket), notice: "工单已关闭"
  end

  # Reopen
  member_action :reopen, method: :put do
    ticket = Ticket.find(params[:id])
    ticket.resolved_at = nil
    ticket.closed_at   = nil
    ticket.reopen!

    AuditService.log!(
      action: "ticket_reopen", actor: current_admin_user, target: ticket,
      after: { status: "open" }, request: request
    )

    redirect_to admin_ticket_path(ticket), notice: "工单已重新打开"
  end

  # Reply
  member_action :reply, method: [:get, :post] do
    @ticket = Ticket.find(params[:id])

    if request.get?
      render "admin/tickets/reply"
    elsif request.post?
      msg = @ticket.messages.build(
        sender_id:   AuditService.format_as_uuid(current_admin_user.id),
        sender_type: "AdminUser",
        content:     params[:content],
        internal:    params[:internal] == "1"
      )

      if msg.save
        AuditService.log!(
          action: "ticket_reply", actor: current_admin_user, target: @ticket,
          metadata: { message_id: msg.id, internal: msg.internal? },
          request: request
        )
        redirect_to admin_ticket_path(@ticket), notice: "回复成功"
      else
        flash[:alert] = "回复失败：#{msg.errors.full_messages.join(', ')}"
        render "admin/tickets/reply"
      end
    end
  end
end
