# frozen_string_literal: true

ActiveAdmin.register Payment do
  menu parent: proc { I18n.t('admin.menu.orders') }, priority: 2, label: proc { I18n.t('admin.labels.payments') }

  # Read-only
  actions :index, :show

  # === Scopes ===
  scope :all, default: true
  scope :pending, label: proc { I18n.t('admin.scopes.pending_payment') } do |scope|
    scope.where(status: %w[init pending])
  end
  scope :paid, label: proc { I18n.t('admin.scopes.paid') } do |scope|
    scope.where(status: 'paid')
  end
  scope :failed, label: proc { I18n.t('admin.scopes.failed') } do |scope|
    scope.where(status: 'failed')
  end
  scope :refunded, label: proc { I18n.t('admin.scopes.refunded') } do |scope|
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
