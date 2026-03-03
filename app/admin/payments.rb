# frozen_string_literal: true

ActiveAdmin.register Payment do
  menu parent: 'orders_menu', priority: 2, label: proc { I18n.t('admin.labels.payments') }

  # Read-only
  actions :index, :show

  # === Scopes ===
  scope :all, default: true
  scope proc { I18n.t('admin.scopes.pending_payment') }, :pending do |scope|
    scope.where(status: %w[init pending])
  end
  scope proc { I18n.t('admin.scopes.paid') }, :paid do |scope|
    scope.where(status: 'paid')
  end
  scope proc { I18n.t('admin.scopes.failed') }, :failed do |scope|
    scope.where(status: 'failed')
  end
  scope proc { I18n.t('admin.scopes.refunded') }, :refunded do |scope|
    scope.where(status: 'refunded')
  end

  # === Filters ===
  filter :order_id
  filter :channel, as: :select, collection: Payment::CHANNELS.map { |c|
    [I18n.t("payment_channels.#{c}", default: c.humanize), c]
  }
  filter :status, as: :select, collection: Payment::STATUSES.map { |s|
    [I18n.t("payment_statuses.#{s}", default: s.humanize), s]
  }
  filter :amount
  filter :provider_trade_no
  filter :paid_at
  filter :created_at

  # === Index ===
  index do
    selectable_column
    id_column
    column I18n.t('admin.columns.related_order') do |payment|
      link_to payment.order.order_no, admin_order_path(payment.order) if payment.order
    end
    column I18n.t('admin.columns.channel') do |payment|
      payment.channel_label
    end
    column I18n.t('admin.columns.amount') do |payment|
      number_to_currency(payment.amount, unit: payment.currency == 'CNY' ? '¥' : '$')
    end
    column I18n.t('admin.columns.status') do |payment|
      status_color = case payment.status
                     when 'paid' then 'yes'
                     when 'failed' then 'error'
                     when 'pending' then 'warning'
                     else nil
                     end
      status_tag payment.status_label, class: status_color
    end
    column I18n.t('admin.columns.provider_trade_no'), :provider_trade_no
    column I18n.t('admin.columns.payment_time'), :paid_at
    column I18n.t('admin.columns.created_time'), :created_at
    actions name: I18n.t('admin.columns.actions'), defaults: false do |payment|
      item I18n.t('admin.actions.view'), admin_payment_path(payment)
    end
  end

  # === Show ===
  show title: proc { |p| I18n.t('admin.titles.payment_record', id: p.id) } do
    attributes_table do
      row('ID') { |p| p.id }
      row(I18n.t('admin.columns.related_order')) { |p| link_to p.order.order_no, admin_order_path(p.order) if p.order }
      row(I18n.t('admin.columns.channel')) { |p| p.channel_label }
      row(I18n.t('admin.columns.amount')) { |p| number_to_currency(p.amount, unit: p.currency == 'CNY' ? '¥' : '$') }
      row(I18n.t('admin.columns.status')) do |p|
        status_color = case p.status
                       when 'paid' then 'yes'
                       when 'failed' then 'error'
                       when 'pending' then 'warning'
                       else nil
                       end
        status_tag p.status_label, class: status_color
      end
      row(I18n.t('admin.columns.provider_trade_no')) { |p| p.provider_trade_no }
      row(:idempotency_key) { |p| p.idempotency_key }
      row(I18n.t('admin.columns.payment_time')) { |p| l(p.paid_at, format: :long) if p.paid_at }
      row(:created_at) { |p| l(p.created_at, format: :long) if p.created_at }
    end

    if payment.status == 'failed'
      panel I18n.t("admin.panels.payment_error_info", default: "异常信息") do
        attributes_table_for payment do
          row(I18n.t("admin.columns.failure_reason", default: "失败原因")) { |p| p.failure_reason }
          row(I18n.t("admin.columns.failed_at", default: "失败时间")) { |p| l(p.updated_at, format: :long) }
          row(I18n.t("admin.columns.third_party_error_code", default: "第三方错误码")) do |p|
            p.response_payload&.dig('error_code') || p.response_payload&.dig('sub_code') || "-"
          end
        end

        if current_admin_user.admin_can?("payment:manage")
          panel I18n.t("admin.panels.raw_payload", default: "原始回调数据（仅超管或有权限者可见）") do
            if payment.notify_payload.present?
              h4 "Notify Payload"
              pre JSON.pretty_generate(payment.notify_payload) rescue payment.notify_payload.to_s
            end
            
            if payment.response_payload.present?
              h4 "Response Payload"
              pre JSON.pretty_generate(payment.response_payload) rescue payment.response_payload.to_s
            end
          end
        end
      end
    end

    panel I18n.t('admin.panels.related_refunds') do
      if payment.refunds.any?
        table_for payment.refunds do
          column('ID') { |r| link_to r.id, admin_refund_path(r) }
          column(I18n.t('admin.columns.amount')) { |r| number_to_currency(r.amount, unit: '¥') }
          column(I18n.t('admin.columns.reason')) { |r| r.reason }
          column(I18n.t('admin.columns.status')) { |r| status_tag r.status_label }
          column(:created_at) { |r| l(r.created_at, format: :short) if r.created_at }
        end
      else
        para I18n.t('admin.messages.no_related_refunds')
      end
    end
  end

  # === CSV Export ===
  csv do
    column :id
    column(I18n.t('admin.columns.order_no')) { |p| p.order&.order_no }
    column :channel
    column :amount
    column :currency
    column :status
    column :provider_trade_no
    column :paid_at
    column :created_at
  end
end
