# frozen_string_literal: true

ActiveAdmin.register Order do
  menu parent: '订单管理', priority: 1, label: '订单列表'

  # Read-only
  actions :index, :show

  # === Scopes ===
  scope :all, default: true
  scope('待支付') { |scope| scope.where(status: 'created') }
  scope('已支付') { |scope| scope.where(status: 'paid') }
  scope('进行中') { |scope| scope.where(status: %w[accepted producing]) }
  scope('已完成') { |scope| scope.where(status: 'completed') }
  scope('已取消') { |scope| scope.where(status: 'canceled') }
  scope('已退款') { |scope| scope.where(status: 'refunded') }

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
    column '订单号', :order_no
    column '买家' do |order|
      order.customer_user&.email || order.customer_id
    end
    column '商家' do |order|
      order.merchant_user&.email || order.merchant_id || '-'
    end
    column '金额' do |order|
      number_to_currency(order.total_amount, unit: order.currency == 'CNY' ? '¥' : '$')
    end
    column '状态' do |order|
      status_color = case order.status.to_s
                     when 'completed' then 'yes'
                     when 'canceled', 'refunded' then 'error'
                     when 'paid', 'accepted' then 'warning'
                     else nil
                     end
      status_tag I18n.t("order_statuses.#{order.status}", default: order.status.to_s.humanize),
                 class: status_color
    end
    column '创建时间', :created_at
    column '支付时间', :paid_at
    actions name: '操作', defaults: false do |order|
      item '查看', admin_order_path(order)
    end
  end

  # === Show ===
  show title: proc { |o| "订单 - #{o.order_no}" } do
    columns do
      column do
        panel '订单信息' do
          attributes_table_for order do
            row('订单号') { |o| o.order_no }
            row('状态') do |o|
              status_color = case o.status.to_s
                             when 'completed' then 'yes'
                             when 'canceled', 'refunded' then 'error'
                             when 'paid', 'accepted' then 'warning'
                             else nil
                             end
              status_tag I18n.t("order_statuses.#{o.status}", default: o.status.to_s.humanize),
                         class: status_color
            end
            row('买家') { |o| o.customer_user&.email || o.customer_id }
            row('商家') { |o| o.merchant_user&.email || o.merchant_id || '-' }
            row('总金额') { |o| number_to_currency(o.total_amount, unit: o.currency == 'CNY' ? '¥' : '$') }
            row('取消原因') { |o| o.cancel_reason } if order.canceled?
          end
        end

        panel '时间线' do
          attributes_table_for order do
            row('创建时间') { |o| l(o.created_at, format: :long) if o.created_at }
            row('支付时间') { |o| l(o.paid_at, format: :long) if o.paid_at }
            row('接单时间') { |o| l(o.accepted_at, format: :long) if o.accepted_at }
            row('制作时间') { |o| l(o.producing_at, format: :long) if o.producing_at }
            row('发货时间') { |o| l(o.delivered_at, format: :long) if o.delivered_at }
            row('完成时间') { |o| l(o.completed_at, format: :long) if o.completed_at }
            row('取消时间') { |o| l(o.canceled_at, format: :long) if o.canceled_at }
          end
        end
      end

      column do
        panel '订单明细' do
          if order.order_items.any?
            table_for order.order_items do
              column('商品') { |item| item.name || "#{item.item_type}##{item.item_id}" }
              column('单价') { |item| number_to_currency(item.unit_price, unit: '¥') if item.unit_price }
              column('数量') { |item| item.quantity }
              column('小计') { |item| number_to_currency(item.subtotal, unit: '¥') if item.subtotal }
            end
          else
            para '暂无订单明细'
          end
        end

        panel '竞价记录' do
          if order.bids.any?
            table_for order.bids.order(created_at: :desc) do
              column('出价人') { |bid| bid.bidder&.email || bid.bidder_id }
              column('金额') { |bid| number_to_currency(bid.amount, unit: '¥') }
              column('状态') do |bid|
                status_color = bid.accepted? ? 'yes' : (bid.rejected? ? 'error' : nil)
                status_tag bid.status_label, class: status_color
              end
              column('时间') { |bid| l(bid.created_at, format: :short) if bid.created_at }
            end
          else
            para '暂无竞价记录'
          end
        end
      end
    end

    panel '支付记录' do
      if order.payments.any?
        table_for order.payments do
          column('ID') { |p| link_to p.id, admin_payment_path(p) }
          column('渠道') { |p| p.channel_label }
          column('金额') { |p| number_to_currency(p.amount, unit: '¥') }
          column('状态') do |p|
            status_color = case p.status
                           when 'paid' then 'yes'
                           when 'failed' then 'error'
                           else nil
                           end
            status_tag p.status_label, class: status_color
          end
          column('支付时间') { |p| l(p.paid_at, format: :short) if p.paid_at }
        end
      else
        para '暂无支付记录'
      end
    end

    panel '退款记录' do
      if order.refunds.any?
        table_for order.refunds do
          column('ID') { |r| link_to r.id, admin_refund_path(r) }
          column('金额') { |r| number_to_currency(r.amount, unit: '¥') }
          column('原因') { |r| r.reason }
          column('状态') do |r|
            status_color = case r.status
                           when 'succeeded' then 'yes'
                           when 'failed' then 'error'
                           else nil
                           end
            status_tag r.status_label, class: status_color
          end
          column('成功时间') { |r| l(r.succeeded_at, format: :short) if r.succeeded_at }
        end
      else
        para '暂无退款记录'
      end
    end
  end

  # === CSV Export ===
  csv do
    column :id
    column :order_no
    column('买家') { |o| o.customer_user&.email }
    column('商家') { |o| o.merchant_user&.email }
    column :total_amount
    column :currency
    column :status
    column :created_at
    column :paid_at
    column :completed_at
  end
end
