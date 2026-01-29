# frozen_string_literal: true

ActiveAdmin.register Refund do
  menu parent: proc { I18n.t('admin.menu.orders') }, priority: 3, label: proc { I18n.t('admin.labels.refunds') }

  # Read-only
  actions :index, :show

  # === Scopes ===
  scope :all, default: true
  scope :processing, label: proc { I18n.t('admin.scopes.processing') } do |scope|
    scope.where(status: %w[init pending])
  end
  scope :succeeded, label: proc { I18n.t('admin.scopes.succeeded') } do |scope|
    scope.where(status: 'succeeded')
  end
  scope :failed, label: proc { I18n.t('admin.scopes.failed') } do |scope|
    scope.where(status: 'failed')
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
    column I18n.t('admin.columns.related_order') do |refund|
      link_to refund.order.order_no, admin_order_path(refund.order) if refund.order
    end
    column I18n.t('admin.columns.related_payment') do |refund|
      link_to "##{refund.payment_id}", admin_payment_path(refund.payment) if refund.payment
    end
    column I18n.t('admin.columns.amount') do |refund|
      number_to_currency(refund.amount, unit: '¥')
    end
    column I18n.t('admin.columns.reason'), :reason
    column I18n.t('admin.columns.status') do |refund|
      status_color = case refund.status
                     when 'succeeded' then 'yes'
                     when 'failed' then 'error'
                     when 'pending' then 'warning'
                     else nil
                     end
      status_tag refund.status_label, class: status_color
    end
    column I18n.t('admin.columns.success_time'), :succeeded_at
    column I18n.t('admin.columns.created_time'), :created_at
    actions name: I18n.t('admin.columns.actions'), defaults: false do |refund|
      item I18n.t('admin.actions.view'), admin_refund_path(refund)
    end
  end

  # === Show ===
  show title: proc { |r| I18n.t('admin.titles.refund_record', id: r.id) } do
    attributes_table do
      row('ID') { |r| r.id }
      row(I18n.t('admin.columns.related_order')) { |r| link_to r.order.order_no, admin_order_path(r.order) if r.order }
      row(I18n.t('admin.columns.related_payment')) { |r| link_to "##{r.payment_id}", admin_payment_path(r.payment) if r.payment }
      row(I18n.t('admin.columns.amount')) { |r| number_to_currency(r.amount, unit: '¥') }
      row(I18n.t('admin.columns.reason')) { |r| r.reason }
      row(I18n.t('admin.columns.status')) do |r|
        status_color = case r.status
                       when 'succeeded' then 'yes'
                       when 'failed' then 'error'
                       when 'pending' then 'warning'
                       else nil
                       end
        status_tag r.status_label, class: status_color
      end
      row(:provider_refund_no) { |r| r.provider_refund_no }
      row(:idempotency_key) { |r| r.idempotency_key }
      row(:requester) { |r| r.requester&.email || r.requested_by_id }
      row(I18n.t('admin.columns.success_time')) { |r| l(r.succeeded_at, format: :long) if r.succeeded_at }
      row(:created_at) { |r| l(r.created_at, format: :long) if r.created_at }
    end
  end

  # === CSV Export ===
  csv do
    column :id
    column(I18n.t('admin.columns.order_no')) { |r| r.order&.order_no }
    column :payment_id
    column :amount
    column :reason
    column :status
    column :provider_refund_no
    column :succeeded_at
    column :created_at
  end
end
