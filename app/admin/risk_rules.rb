# frozen_string_literal: true

ActiveAdmin.register RiskRule do
  menu parent: "orders_menu", priority: 6, label: proc { I18n.t('admin.labels.risk_rules', default: '风控规则') }

  permit_params :code, :name, :description, :category, :severity, :enabled

  # === Scopes ===
  scope :all, default: true
  scope("已启用") { |s| s.enabled }
  scope("已禁用") { |s| s.disabled }

  # === Index ===
  index do
    selectable_column
    id_column
    column("规则代码", :code)
    column("名称", :name)
    column("分类") { |r| status_tag r.category_label }
    column("严重级") do |r|
      color = case r.severity
              when "critical" then "error"
              when "high"     then "warning"
              else nil
              end
      status_tag r.severity_label, class: color
    end
    column("状态") { |r| status_tag(r.enabled? ? "已启用" : "已禁用", class: r.enabled? ? "yes" : "no") }
    column("参数") { |r| code(r.params.to_json) }
    column("事件数") { |r| r.risk_events.pending.count }
    column("创建时间", :created_at)
    actions name: "操作"
  end

  # === Filters ===
  filter :code
  filter :name
  filter :category, as: :select, collection: -> {
    RiskRule::CATEGORIES.map { |c| [I18n.t("risk_categories.#{c}", default: c.humanize), c] }
  }
  filter :severity, as: :select, collection: -> {
    RiskRule::SEVERITIES.map { |s| [I18n.t("risk_severities.#{s}", default: s.humanize), s] }
  }
  filter :enabled

  # === Show ===
  show title: proc { |r| I18n.t('admin.titles.risk_rule', name: r.name, default: "风控规则: #{r.name}") } do
    attributes_table do
      row("代码")   { |r| r.code }
      row("名称")   { |r| r.name }
      row("描述")   { |r| r.description }
      row("分类")   { |r| status_tag r.category_label }
      row("严重级") do |r|
        color = case r.severity
                when "critical" then "error"
                when "high"     then "warning"
                else nil
                end
        status_tag r.severity_label, class: color
      end
      row("状态")   { |r| status_tag(r.enabled? ? "已启用" : "已禁用", class: r.enabled? ? "yes" : "no") }
      row("参数")   { |r| pre JSON.pretty_generate(r.params) }
    end

    panel "最近风控事件 (#{risk_rule.risk_events.count})" do
      if risk_rule.risk_events.any?
        table_for risk_rule.risk_events.order(created_at: :desc).limit(20) do
          column("ID") { |e| link_to e.id, admin_risk_event_path(e) }
          column("主体") { |e| e.subject&.email || e.subject_id }
          column("状态") do |e|
            color = case e.status
                    when "processed" then "yes"
                    when "ignored"   then nil
                    else "warning"
                    end
            status_tag e.status_label, class: color
          end
          column("触发来源", :trigger_source)
          column("创建时间") { |e| l(e.created_at, format: :short) if e.created_at }
        end
      else
        para "暂无风控事件"
      end
    end
  end

  # === Form ===
  form title: proc { |r| r.new_record? ? "新建规则" : "编辑规则" } do |f|
    f.inputs "规则信息" do
      f.input :code,        label: "规则代码", hint: "英文小写+下划线，如: high_freq_refund"
      f.input :name,        label: "名称"
      f.input :description, label: "描述", as: :text
      f.input :category,    label: "分类", as: :select,
              collection: RiskRule::CATEGORIES.map { |c| [I18n.t("risk_categories.#{c}", default: c.humanize), c] },
              include_blank: false
      f.input :severity,    label: "严重级", as: :select,
              collection: RiskRule::SEVERITIES.map { |s| [I18n.t("risk_severities.#{s}", default: s.humanize), s] },
              include_blank: false
      f.input :enabled,     label: "启用"
    end
    f.actions
  end
end
