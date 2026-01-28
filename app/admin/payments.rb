# frozen_string_literal: true

ActiveAdmin.register Payment do
  menu parent: '订单管理', priority: 2, label: '支付记录'

  # Read-only
  actions :index, :show

  # === Scopes ===
  scope :all, default: true
  scope('待支付') { |scope| scope.where(status: %w[init pending]) }
  scope('已支付') { |scope| scope.where(status: 'paid') }
  scope('支付失败') { |scope| scope.where(status: 'failed') }
  scope('已退款') { |scope| scope.where(status: 'refunded') }

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
    column '关联订单' do |payment|
      link_to payment.order.order_no, admin_order_path(payment.order) if payment.order
    end
    column '渠道' do |payment|
      payment.channel_label
    end
    column '金额' do |payment|
      number_to_currency(payment.amount, unit: payment.currency == 'CNY' ? '¥' : '$')
    end
    column '状态' do |payment|
      status_color = case payment.status
                     when 'paid' then 'yes'
                     when 'failed' then 'error'
                     when 'pending' then 'warning'
                     else nil
                     end
      status_tag payment.status_label, class: status_color
    end
    column '第三方交易号', :provider_trade_no
    column '支付时间', :paid_at
    column '创建时间', :created_at
    actions name: '操作', defaults: false do |payment|
      item '查看', admin_payment_path(payment)
    end
  end

  # === Show ===
  show title: proc { |p| "支付记录 ##{p.id}" } do
    attributes_table do
      row('ID') { |p| p.id }
      row('关联订单') { |p| link_to p.order.order_no, admin_order_path(p.order) if p.order }
      row('渠道') { |p| p.channel_label }
      row('金额') { |p| number_to_currency(p.amount, unit: p.currency == 'CNY' ? '¥' : '$') }
      row('状态') do |p|
        status_color = case p.status
                       when 'paid' then 'yes'
                       when 'failed' then 'error'
                       when 'pending' then 'warning'
                       else nil
                       end
        status_tag p.status_label, class: status_color
      end
      row('第三方交易号') { |p| p.provider_trade_no }
      row('幂等键') { |p| p.idempotency_key }
      row('支付时间') { |p| l(p.paid_at, format: :long) if p.paid_at }
      row('创建时间') { |p| l(p.created_at, format: :long) if p.created_at }
    end

    panel '关联退款' do
      if payment.refunds.any?
        table_for payment.refunds do
          column('ID') { |r| link_to r.id, admin_refund_path(r) }
          column('金额') { |r| number_to_currency(r.amount, unit: '¥') }
          column('原因') { |r| r.reason }
          column('状态') { |r| status_tag r.status_label }
          column('时间') { |r| l(r.created_at, format: :short) if r.created_at }
        end
      else
        para '暂无关联退款'
      end
    end
  end

  # === CSV Export ===
  csv do
    column :id
    column('订单号') { |p| p.order&.order_no }
    column :channel
    column :amount
    column :currency
    column :status
    column :provider_trade_no
    column :paid_at
    column :created_at
  end
end
