# frozen_string_literal: true

ActiveAdmin.register Order do
  menu parent: proc { I18n.t('admin.menu.orders') }, priority: 1, label: proc { I18n.t('admin.labels.orders') }

  # Read-only
  actions :index, :show

  # === Scopes ===
  scope :all, default: true
  scope :pending_payment, label: proc { I18n.t('admin.scopes.pending_payment') } do |scope|
    scope.where(status: 'created')
  end
  scope :paid, label: proc { I18n.t('admin.scopes.paid') } do |scope|
    scope.where(status: 'paid')
  end
  scope :in_progress, label: proc { I18n.t('admin.scopes.in_progress') } do |scope|
    scope.where(status: %w[accepted producing])
  end
  scope :completed, label: proc { I18n.t('admin.scopes.completed') } do |scope|
    scope.where(status: 'completed')
  end
  scope :canceled, label: proc { I18n.t('admin.scopes.canceled') } do |scope|
    scope.where(status: 'canceled')
  end
  scope :refunded, label: proc { I18n.t('admin.scopes.refunded') } do |scope|
    scope.where(status: 'refunded')
  end

  # === Filters ===
  filter :order_no
  filter :status, as: :select, collection: -> {
    Order.distinct.pluck(:status).compact.map { |s|
      [I18n.t("order_statuses.#{s}", default: s.humanize), s]
    }
  }
  filter :total_amount
  filter :currency, as: :select, collection: %w[CNY USD]
  filter :created_at
  filter :paid_at
  filter :completed_at

  # === Index ===
  index do
    selectable_column
    id_column
    column I18n.t('admin.columns.order_no'), :order_no
    column I18n.t('admin.columns.buyer') do |order|
      order.customer_user&.email || order.customer_id
    end
    column I18n.t('admin.columns.merchant') do |order|
      order.merchant_user&.email || order.merchant_id || '-'
    end
    column I18n.t('admin.columns.amount') do |order|
      number_to_currency(order.total_amount, unit: order.currency == 'CNY' ? '¥' : '$')
    end
    column I18n.t('admin.columns.status') do |order|
      status_color = case order.status.to_s
                     when 'completed' then 'yes'
                     when 'canceled', 'refunded' then 'error'
                     when 'paid', 'accepted' then 'warning'
                     else nil
                     end
      status_tag I18n.t("order_statuses.#{order.status}", default: order.status.to_s.humanize),
                 class: status_color
    end
    column I18n.t('admin.columns.created_time'), :created_at
    column I18n.t('admin.columns.payment_time'), :paid_at
    actions name: I18n.t('admin.columns.actions'), defaults: false do |order|
      item I18n.t('admin.actions.view'), admin_order_path(order)
    end
  end

  # === Show ===
  show title: proc { |o| I18n.t('admin.titles.order', order_no: o.order_no) } do
    columns do
      column do
        panel I18n.t('admin.panels.order_info') do
          attributes_table_for order do
            row(I18n.t('admin.columns.order_no')) { |o| o.order_no }
            row(I18n.t('admin.columns.status')) do |o|
              status_color = case o.status.to_s
                             when 'completed' then 'yes'
                             when 'canceled', 'refunded' then 'error'
                             when 'paid', 'accepted' then 'warning'
                             else nil
                             end
              status_tag I18n.t("order_statuses.#{o.status}", default: o.status.to_s.humanize),
                         class: status_color
            end
            row(I18n.t('admin.columns.buyer')) { |o| o.customer_user&.email || o.customer_id }
            row(I18n.t('admin.columns.merchant')) { |o| o.merchant_user&.email || o.merchant_id || '-' }
            row(I18n.t('admin.columns.amount')) { |o| number_to_currency(o.total_amount, unit: o.currency == 'CNY' ? '¥' : '$') }
            row(:cancel_reason) { |o| o.cancel_reason } if order.canceled?
          end
        end

        panel I18n.t('admin.panels.timeline') do
          attributes_table_for order do
            row(:created_at) { |o| l(o.created_at, format: :long) if o.created_at }
            row(:paid_at) { |o| l(o.paid_at, format: :long) if o.paid_at }
            row(:accepted_at) { |o| l(o.accepted_at, format: :long) if o.accepted_at }
            row(:producing_at) { |o| l(o.producing_at, format: :long) if o.producing_at }
            row(:delivered_at) { |o| l(o.delivered_at, format: :long) if o.delivered_at }
            row(:completed_at) { |o| l(o.completed_at, format: :long) if o.completed_at }
            row(:canceled_at) { |o| l(o.canceled_at, format: :long) if o.canceled_at }
          end
        end
      end

      column do
        panel I18n.t('admin.panels.order_items') do
          if order.order_items.any?
            table_for order.order_items do
              column(:name) { |item| item.name || "#{item.item_type}##{item.item_id}" }
              column(:unit_price) { |item| number_to_currency(item.unit_price, unit: '¥') if item.unit_price }
              column(:quantity) { |item| item.quantity }
              column(:subtotal) { |item| number_to_currency(item.subtotal, unit: '¥') if item.subtotal }
            end
          else
            para I18n.t('admin.messages.no_order_items')
          end
        end

        panel I18n.t('admin.panels.bid_records') do
          if order.bids.any?
            table_for order.bids.order(created_at: :desc) do
              column(:bidder) { |bid| bid.bidder&.email || bid.bidder_id }
              column(I18n.t('admin.columns.amount')) { |bid| number_to_currency(bid.amount, unit: '¥') }
              column(I18n.t('admin.columns.status')) do |bid|
                status_color = bid.accepted? ? 'yes' : (bid.rejected? ? 'error' : nil)
                status_tag bid.status_label, class: status_color
              end
              column(:created_at) { |bid| l(bid.created_at, format: :short) if bid.created_at }
            end
          else
            para I18n.t('admin.messages.no_bid_records')
          end
        end
      end
    end

    panel I18n.t('admin.panels.payment_records') do
      if order.payments.any?
        table_for order.payments do
          column('ID') { |p| link_to p.id, admin_payment_path(p) }
          column(I18n.t('admin.columns.channel')) { |p| p.channel_label }
          column(I18n.t('admin.columns.amount')) { |p| number_to_currency(p.amount, unit: '¥') }
          column(I18n.t('admin.columns.status')) do |p|
            status_color = case p.status
                           when 'paid' then 'yes'
                           when 'failed' then 'error'
                           else nil
                           end
            status_tag p.status_label, class: status_color
          end
          column(I18n.t('admin.columns.payment_time')) { |p| l(p.paid_at, format: :short) if p.paid_at }
        end
      else
        para I18n.t('admin.messages.no_payment_records')
      end
    end

    panel I18n.t('admin.panels.refund_records') do
      if order.refunds.any?
        table_for order.refunds do
          column('ID') { |r| link_to r.id, admin_refund_path(r) }
          column(I18n.t('admin.columns.amount')) { |r| number_to_currency(r.amount, unit: '¥') }
          column(I18n.t('admin.columns.reason')) { |r| r.reason }
          column(I18n.t('admin.columns.status')) do |r|
            status_color = case r.status
                           when 'succeeded' then 'yes'
                           when 'failed' then 'error'
                           else nil
                           end
            status_tag r.status_label, class: status_color
          end
          column(I18n.t('admin.columns.success_time')) { |r| l(r.succeeded_at, format: :short) if r.succeeded_at }
        end
      else
        para I18n.t('admin.messages.no_refund_records')
      end
    end
  end

  # === CSV Export ===
  csv do
    column :id
    column :order_no
    column(I18n.t('admin.columns.buyer')) { |o| o.customer_user&.email }
    column(I18n.t('admin.columns.merchant')) { |o| o.merchant_user&.email }
    column :total_amount
    column :currency
    column :status
    column :created_at
    column :paid_at
    column :completed_at
  end
end
