# frozen_string_literal: true

ActiveAdmin.register EtlCleanRule do
  menu parent: "etl_menu", priority: 2,
       label: proc { I18n.t("admin.etl.menu.clean_rules", default: "清洗规则") }

  filter :name
  filter :source_table, as: :string
  filter :rule_type, as: :select, collection: EtlCleanRule::RULE_TYPES
  filter :action, as: :select, collection: EtlCleanRule::ACTIONS
  filter :is_active

  index do
    column :name
    column I18n.t("admin.etl.clean_rule.source_table", default: "源表"), :source_table
    column I18n.t("admin.etl.clean_rule.target_field", default: "目标字段"), :target_field
    column I18n.t("admin.etl.clean_rule.rule_type", default: "规则类型"), :rule_type
    column I18n.t("admin.etl.clean_rule.action", default: "动作"), :action
    column I18n.t("admin.etl.clean_rule.priority", default: "优先级"), :priority
    column I18n.t("admin.etl.clean_rule.is_active", default: "启用") do |rule|
      status_tag rule.is_active ? 'active' : 'inactive'
    end
    actions
  end

  show do
    attributes_table do
      row :name
      row :source_table
      row :target_field
      row :rule_type
      row :action
      row :priority
      row :is_active
      row :description
      row I18n.t("admin.etl.clean_rule.params", default: "规则参数") do |rule|
        pre rule.params.to_json
      end
    end

    panel I18n.t("admin.etl.clean_rule.recent_logs", default: "最近清洗日志 (最新50条)") do
      logs = resource.etl_clean_logs.order(created_at: :desc).limit(50)
      table_for logs do
        column I18n.t("admin.etl.clean_log.batch_id", default: "批次"), :batch_id
        column :source_record_id
        column :original_value
        column :cleaned_value
        column :action_taken
        column :created_at
      end
    end
  end

  form do |f|
    f.inputs I18n.t("admin.etl.clean_rule.basic_info", default: "基本信息") do
      f.input :name
      f.input :source_table, as: :select,
              collection: Etl::Pipeline.all_sources,
              include_blank: false
      f.input :target_field
      f.input :rule_type, as: :select,
              collection: EtlCleanRule::RULE_TYPES,
              include_blank: false
      f.input :action, as: :select,
              collection: EtlCleanRule::ACTIONS,
              include_blank: false
      f.input :priority
      f.input :is_active
      f.input :description, as: :text
    end

    f.inputs I18n.t("admin.etl.clean_rule.params_config", default: "规则参数 (JSON)") do
      f.input :params, as: :text, input_html: { rows: 5,
        placeholder: '{"min": 0, "max": 99999, "default": 0}' }
    end

    f.actions
  end
end
