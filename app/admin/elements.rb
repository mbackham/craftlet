# frozen_string_literal: true

ActiveAdmin.register Element do
  menu parent: '运营管理', priority: 1, label: '元素库'

  permit_params :name, :category, :status, :price, :oss_key, :thumbnail_key, :description

  controller do
    include Auditable
    helper AuditHelper

    after_action :audit_create, only: [:create]
    after_action :audit_update, only: [:update]
    after_action :audit_destroy, only: [:destroy]
  end

  # === Scopes ===
  scope :all, default: true
  scope('草稿') { |scope| scope.draft }
  scope('已上架') { |scope| scope.on_shelf }
  scope('已下架') { |scope| scope.off_shelf }

  # === Filters ===
  filter :name
  filter :category, as: :select, collection: Element::CATEGORIES.map { |c|
    [I18n.t("element_categories.#{c}", default: c.humanize), c]
  }
  filter :status, as: :select, collection: Element::STATUSES.map { |s|
    [I18n.t("element_statuses.#{s}", default: s.humanize), s]
  }
  filter :price
  filter :created_at
  filter :shelved_at
  filter :unshelved_at

  # === Index ===
  index do
    selectable_column
    id_column
    column '名称', :name
    column '分类' do |el|
      I18n.t("element_categories.#{el.category}", default: el.category) if el.category
    end
    column '价格' do |el|
      number_to_currency(el.price, unit: '¥') if el.price
    end
    column '状态' do |el|
      status_color = case el.status
                     when 'on_shelf' then 'yes'
                     when 'off_shelf' then 'no'
                     else nil
                     end
      status_tag I18n.t("element_statuses.#{el.status}", default: el.status.humanize),
                 class: status_color
    end
    column '上架时间', :shelved_at
    column '创建时间', :created_at
    actions name: '操作'
  end

  # === Show ===
  show title: proc { |el| "元素 - #{el.name}" } do
    attributes_table do
      row('ID') { |el| el.id }
      row('名称') { |el| el.name }
      row('分类') { |el| I18n.t("element_categories.#{el.category}", default: el.category) if el.category }
      row('价格') { |el| number_to_currency(el.price, unit: '¥') if el.price }
      row('状态') do |el|
        status_color = case el.status
                       when 'on_shelf' then 'yes'
                       when 'off_shelf' then 'no'
                       else nil
                       end
        status_tag I18n.t("element_statuses.#{el.status}", default: el.status.humanize),
                   class: status_color
      end
      row('描述') { |el| el.description }
      row('OSS Key') { |el| el.oss_key }
      row('缩略图 Key') { |el| el.thumbnail_key }
      row('上架时间') { |el| l(el.shelved_at, format: :long) if el.shelved_at }
      row('下架时间') { |el| l(el.unshelved_at, format: :long) if el.unshelved_at }
      row('创建时间') { |el| l(el.created_at, format: :long) if el.created_at }
      row('更新时间') { |el| l(el.updated_at, format: :long) if el.updated_at }
    end

    panel '审计日志' do
      audit_logs = AuditLog.where(target_type: 'Element', target_id: element.id)
                           .order(created_at: :desc).limit(10)
      if audit_logs.any?
        table_for audit_logs do
          column('操作') { |log| status_tag log.action }
          column('操作人') { |log| log.actor&.email || '系统' }
          column('时间') { |log| l(log.created_at, format: :long) if log.created_at }
        end
      else
        para '暂无审计日志'
      end
    end
  end

  # === Form ===
  form do |f|
    f.inputs '基本信息' do
      f.input :name
      f.input :category, as: :select, collection: Element::CATEGORIES.map { |c|
        [I18n.t("element_categories.#{c}", default: c.humanize), c]
      }, include_blank: '请选择分类'
      f.input :price
      f.input :description
    end

    f.inputs '文件信息' do
      f.input :oss_key, hint: 'OSS 文件 Key'
      f.input :thumbnail_key, hint: '缩略图 OSS Key'
    end

    f.actions
  end

  # === Member Actions ===
  member_action :shelf, method: :put do
    element = Element.find(params[:id])
    
    unless element.can_shelf?
      redirect_to admin_element_path(element), alert: '当前状态不允许上架'
      return
    end

    ActiveRecord::Base.transaction do
      old_status = element.status
      element.shelf!

      AuditService.log!(
        action: 'shelf',
        actor: current_admin_user,
        target: element,
        before: { status: old_status },
        after: { status: 'on_shelf', shelved_at: element.shelved_at },
        metadata: { action_type: 'element_shelf' },
        request: request
      )
    end

    redirect_to admin_element_path(element), notice: '元素已上架'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_element_path(element), alert: "操作失败: #{e.message}"
  end

  member_action :unshelf, method: :put do
    element = Element.find(params[:id])
    
    unless element.can_unshelf?
      redirect_to admin_element_path(element), alert: '当前状态不允许下架'
      return
    end

    ActiveRecord::Base.transaction do
      old_status = element.status
      element.unshelf!

      AuditService.log!(
        action: 'unshelf',
        actor: current_admin_user,
        target: element,
        before: { status: old_status },
        after: { status: 'off_shelf', unshelved_at: element.unshelved_at },
        metadata: { action_type: 'element_unshelf' },
        request: request
      )
    end

    redirect_to admin_element_path(element), notice: '元素已下架'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_element_path(element), alert: "操作失败: #{e.message}"
  end

  # === Action Items ===
  action_item :shelf, only: :show, if: proc { element.can_shelf? } do
    link_to '上架', shelf_admin_element_path(element),
            method: :put,
            data: { confirm: '确认上架该元素？' },
            class: 'action-item-button'
  end

  action_item :unshelf, only: :show, if: proc { element.can_unshelf? } do
    link_to '下架', unshelf_admin_element_path(element),
            method: :put,
            data: { confirm: '确认下架该元素？' },
            class: 'action-item-button'
  end

  # === Batch Actions ===
  batch_action :shelf do |ids|
    batch_action_collection.find(ids).each do |element|
      next unless element.can_shelf?
      element.shelf!
    end
    redirect_to collection_path, notice: "已批量上架 #{ids.size} 个元素"
  end

  batch_action :unshelf do |ids|
    batch_action_collection.find(ids).each do |element|
      next unless element.can_unshelf?
      element.unshelf!
    end
    redirect_to collection_path, notice: "已批量下架 #{ids.size} 个元素"
  end

  # === CSV Export ===
  csv do
    column :id
    column :name
    column :category
    column :price
    column :status
    column :oss_key
    column :shelved_at
    column :unshelved_at
    column :created_at
  end
end
