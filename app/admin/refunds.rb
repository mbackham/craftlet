# frozen_string_literal: true

ActiveAdmin.register Refund do
  menu parent: '订单管理', priority: 3, label: '退款记录'

  # Read-only
  actions :index, :show

  # === Scopes ===
  scope :all, default: true
  scope('处理中') { |scope| scope.where(status: %w[init pending]) }
  scope('已成功') { |scope| scope.where(status: 'succeeded') }
  scope('已失败') { |scope| scope.where(status: 'failed') }

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
    column '关联订单' do |refund|
      link_to refund.order.order_no, admin_order_path(refund.order) if refund.order
    end
    column '关联支付' do |refund|
      link_to "##{refund.payment_id}", admin_payment_path(refund.payment) if refund.payment
    end
    column '金额' do |refund|
      number_to_currency(refund.amount, unit: '¥')
    end
    column '原因', :reason
    column '状态' do |refund|
      status_color = case refund.status
                     when 'succeeded' then 'yes'
                     when 'failed' then 'error'
                     when 'pending' then 'warning'
                     else nil
                     end
      status_tag refund.status_label, class: status_color
    end
    column '成功时间', :succeeded_at
    column '创建时间', :created_at
    actions name: '操作', defaults: false do |refund|
      item '查看', admin_refund_path(refund)
    end
  end

  # === Show ===
  show title: proc { |r| "退款记录 ##{r.id}" } do
    attributes_table do
      row('ID') { |r| r.id }
      row('关联订单') { |r| link_to r.order.order_no, admin_order_path(r.order) if r.order }
      row('关联支付') { |r| link_to "##{r.payment_id}", admin_payment_path(r.payment) if r.payment }
      row('金额') { |r| number_to_currency(r.amount, unit: '¥') }
      row('原因') { |r| r.reason }
      row('状态') do |r|
        status_color = case r.status
                       when 'succeeded' then 'yes'
                       when 'failed' then 'error'
                       when 'pending' then 'warning'
                       else nil
                       end
        status_tag r.status_label, class: status_color
      end
      row('第三方退款号') { |r| r.provider_refund_no }
      row('幂等键') { |r| r.idempotency_key }
      row('申请人') { |r| r.requester&.email || r.requested_by_id }
      row('成功时间') { |r| l(r.succeeded_at, format: :long) if r.succeeded_at }
      row('创建时间') { |r| l(r.created_at, format: :long) if r.created_at }
    end
  end

  # === CSV Export ===
  csv do
    column :id
    column('订单号') { |r| r.order&.order_no }
    column :payment_id
    column :amount
    column :reason
    column :status
    column :provider_refund_no
    column :succeeded_at
    column :created_at
  end
end
