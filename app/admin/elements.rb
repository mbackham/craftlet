# frozen_string_literal: true

ActiveAdmin.register Element do
  menu parent: 'operations_menu', priority: 1, label: proc { I18n.t('admin.labels.elements') }

  permit_params :name, :category, :element_type, :material_type, :finish_type,
                :status, :price, :oss_key, :thumbnail_key, :mesh_url, :glb_key,
                :description, :color_hex, :color_name, :size_mm, :weight_g,
                :hole_diameter_mm, :hardness_level, :is_natural, :origin_region,
                tags: []

  controller do
    include Auditable
    helper AuditHelper

    after_action :audit_create, only: [:create]
    after_action :audit_update, only: [:update]
    after_action :audit_destroy, only: [:destroy]
  end

  # === Scopes ===
  scope :all, default: true
  scope proc { I18n.t('admin.scopes.draft') }, :draft
  scope proc { I18n.t('admin.scopes.on_shelf') }, :on_shelf
  scope proc { I18n.t('admin.scopes.off_shelf') }, :off_shelf

  # === Filters ===
  filter :name
  filter :element_type, as: :select, collection: Element::ELEMENT_TYPES.map { |t|
    [I18n.t("element_types.#{t}", default: t.humanize), t]
  }
  filter :material_type, as: :select, collection: Element::MATERIAL_TYPES.map { |t|
    [I18n.t("material_types.#{t}", default: t.humanize), t]
  }
  filter :finish_type, as: :select, collection: Element::FINISH_TYPES.map { |t|
    [I18n.t("finish_types.#{t}", default: t.humanize), t]
  }
  filter :is_natural, as: :boolean
  filter :origin_region
  filter :category, as: :select, collection: Element::CATEGORIES.map { |c|
    [I18n.t("element_categories.#{c}", default: c.humanize), c]
  }
  filter :status, as: :select, collection: Element::STATUSES.map { |s|
    [I18n.t("element_statuses.#{s}", default: s.humanize), s]
  }
  filter :price
  filter :size_mm
  filter :created_at
  filter :shelved_at

  # === Index ===
  index do
    selectable_column
    id_column
    column I18n.t('admin.columns.name'), :name
    column I18n.t('admin.columns.element_type') do |el|
      I18n.t("element_types.#{el.element_type}", default: el.element_type) if el.element_type
    end
    column I18n.t('admin.columns.material_type') do |el|
      I18n.t("material_types.#{el.material_type}", default: el.material_type) if el.material_type
    end
    column I18n.t('admin.columns.color') do |el|
      if el.color_hex
        "<span style='display:inline-block;width:14px;height:14px;background:#{el.color_hex};border-radius:3px;margin-right:4px;vertical-align:middle'></span>#{el.color_name}".html_safe
      end
    end
    column :size_mm
    column I18n.t('admin.columns.price') do |el|
      number_to_currency(el.price, unit: '¥') if el.price
    end
    column I18n.t('admin.columns.status') do |el|
      status_color = case el.status
                     when 'on_shelf' then 'yes'
                     when 'off_shelf' then 'no'
                     else nil
                     end
      status_tag I18n.t("element_statuses.#{el.status}", default: el.status.humanize),
                 class: status_color
    end
    column I18n.t('admin.columns.shelf_time'), :shelved_at
    column I18n.t('admin.columns.created_time'), :created_at
    actions name: I18n.t('admin.columns.actions')
  end

  # === Show ===
  show title: proc { |el| I18n.t('admin.titles.element', name: el.name) } do
    attributes_table do
      row('ID') { |el| el.id }
      row(I18n.t('admin.columns.name')) { |el| el.name }
      row(I18n.t('admin.columns.element_type')) { |el|
        I18n.t("element_types.#{el.element_type}", default: el.element_type) if el.element_type
      }
      row(I18n.t('admin.columns.material_type')) { |el|
        I18n.t("material_types.#{el.material_type}", default: el.material_type) if el.material_type
      }
      row(I18n.t('admin.columns.finish_type')) { |el|
        I18n.t("finish_types.#{el.finish_type}", default: el.finish_type) if el.finish_type
      }
      row(I18n.t('admin.columns.color')) { |el|
        "#{el.color_hex} #{el.color_name}".strip if el.color_hex || el.color_name
      }
      row(:size_mm)
      row(:weight_g)
      row(:hole_diameter_mm)
      row(:hardness_level)
      row(I18n.t('admin.columns.is_natural')) { |el| el.is_natural? ? '✓ 天然' : '仿制' }
      row(:origin_region)
      row(I18n.t('admin.columns.category')) { |el|
        I18n.t("element_categories.#{el.category}", default: el.category) if el.category
      }
      row(I18n.t('admin.columns.price')) { |el| number_to_currency(el.price, unit: '¥') if el.price }
      row(I18n.t('admin.columns.status')) do |el|
        status_color = case el.status
                       when 'on_shelf' then 'yes'
                       when 'off_shelf' then 'no'
                       else nil
                       end
        status_tag I18n.t("element_statuses.#{el.status}", default: el.status.humanize),
                   class: status_color
      end
      row(:tags) { |el| el.tags.join(', ') if el.tags&.any? }
      row(:description) { |el| el.description }
      row('OSS Key') { |el| el.oss_key }
      row(:thumbnail_key) { |el| el.thumbnail_key }
      row(:mesh_url) { |el| el.mesh_url }
      row(:glb_key) { |el| el.glb_key }
      row(I18n.t('admin.columns.shelf_time')) { |el| l(el.shelved_at, format: :long) if el.shelved_at }
      row(:created_at) { |el| l(el.created_at, format: :long) if el.created_at }
    end

    panel I18n.t('admin.panels.audit_logs') do
      audit_logs = AuditLog.where(target_type: 'Element', target_id: element.id)
                           .order(created_at: :desc).limit(10)
      if audit_logs.any?
        table_for audit_logs do
          column(I18n.t('admin.columns.status')) { |log| status_tag log.action }
          column(I18n.t('admin.columns.operator')) { |log| log.actor&.email || I18n.t('admin.messages.system') }
          column(I18n.t('admin.columns.created_time')) { |log| l(log.created_at, format: :long) if log.created_at }
        end
      else
        para I18n.t('admin.messages.no_audit_logs')
      end
    end
  end

  # === Form ===
  form do |f|
    f.inputs I18n.t('admin.panels.basic_info') do
      f.input :name
      f.input :element_type, as: :select,
              collection: Element::ELEMENT_TYPES.map { |t|
                [I18n.t("element_types.#{t}", default: t.humanize), t]
              }, include_blank: '请选择元素类型'
      f.input :material_type, as: :select,
              collection: Element::MATERIAL_TYPES.map { |t|
                [I18n.t("material_types.#{t}", default: t.humanize), t]
              }, include_blank: '请选择材质'
      f.input :finish_type, as: :select,
              collection: Element::FINISH_TYPES.map { |t|
                [I18n.t("finish_types.#{t}", default: t.humanize), t]
              }, include_blank: '请选择工艺'
      f.input :price
      f.input :description
    end

    f.inputs '颜色与规格' do
      f.input :color_hex,  hint: '十六进制颜色，如 #8B4513'
      f.input :color_name, hint: '颜色名称，如 棕色'
      f.input :size_mm,    hint: '珠子直径或绳子线径（毫米）'
      f.input :weight_g,   hint: '单颗/单米重量（克）'
      f.input :hole_diameter_mm, hint: '孔径（毫米，珠子专用）'
      f.input :hardness_level,   hint: '硬度，如 莫氏7级'
    end

    f.inputs '产地与属性' do
      f.input :is_natural,     as: :boolean, hint: '是否天然材质（非仿制）'
      f.input :origin_region,  hint: '产地，如 新疆和田、缅甸'
      f.input :tags,           as: :string,  hint: '逗号分隔的标签，如 辟邪,开运'
    end

    f.inputs '3D 资源' do
      f.input :mesh_url,  hint: '3D 模型公开 URL（CDN 直链）'
      f.input :glb_key,   hint: 'GLB/GLTF 格式 3D 模型 OSS Key'
    end

    f.inputs do
      f.input :oss_key,       hint: I18n.t('admin.forms.oss_key_hint')
      f.input :thumbnail_key, hint: I18n.t('admin.forms.thumbnail_hint')
    end

    f.actions
  end

  # === Member Actions ===
  member_action :shelf, method: :put do
    element = Element.find(params[:id])
    authorize! :shelf, element

    unless element.can_shelf?
      redirect_to admin_element_path(element), alert: I18n.t('admin.alerts.status_not_allow_shelf')
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

    redirect_to admin_element_path(element), notice: I18n.t('admin.notices.element_shelved')
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_element_path(element), alert: I18n.t('admin.notices.operation_failed', error: e.message)
  end

  member_action :unshelf, method: :put do
    element = Element.find(params[:id])
    authorize! :unshelf, element

    unless element.can_unshelf?
      redirect_to admin_element_path(element), alert: I18n.t('admin.alerts.status_not_allow_unshelf')
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

    redirect_to admin_element_path(element), notice: I18n.t('admin.notices.element_unshelved')
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_element_path(element), alert: I18n.t('admin.notices.operation_failed', error: e.message)
  end

  # === Action Items ===
  action_item :shelf, only: :show, if: proc { element.can_shelf? && current_admin_user.admin_can?("element:manage") } do
    link_to I18n.t('admin.actions.shelf'), shelf_admin_element_path(element),
            method: :put,
            data: { confirm: I18n.t('admin.confirmations.shelf_element') },
            class: 'action-item-button'
  end

  action_item :unshelf, only: :show, if: proc { element.can_unshelf? && current_admin_user.admin_can?("element:manage") } do
    link_to I18n.t('admin.actions.unshelf'), unshelf_admin_element_path(element),
            method: :put,
            data: { confirm: I18n.t('admin.confirmations.unshelf_element') },
            class: 'action-item-button'
  end

  # === Batch Actions ===
  batch_action :shelf, if: proc { current_admin_user.admin_can?("element:manage") } do |ids|
    batch_action_collection.find(ids).each do |element|
      next unless element.can_shelf?
      element.shelf!
    end
    redirect_to collection_path, notice: "#{I18n.t('admin.messages.batch_shelved')} #{ids.size}"
  end

  batch_action :unshelf, if: proc { current_admin_user.admin_can?("element:manage") } do |ids|
    batch_action_collection.find(ids).each do |element|
      next unless element.can_unshelf?
      element.unshelf!
    end
    redirect_to collection_path, notice: "#{I18n.t('admin.messages.batch_unshelved')} #{ids.size}"
  end

  # === CSV Export ===
  csv do
    column :id
    column :name
    column :element_type
    column :material_type
    column :finish_type
    column :color_hex
    column :color_name
    column :size_mm
    column :weight_g
    column :is_natural
    column :origin_region
    column :price
    column :status
    column :oss_key
    column :glb_key
    column :shelved_at
    column :created_at
  end
end
