# frozen_string_literal: true

ActiveAdmin.register EtlCleanLog do
  menu parent: "etl_menu", priority: 3,
       label: proc { I18n.t("admin.etl.menu.clean_logs", default: "清洗日志") }

  actions :index, :show

  filter :batch_id, as: :string
  filter :source_table, as: :string
  filter :field_name, as: :string
  filter :action_taken, as: :select, collection: %w[skipped filled transformed flagged]
  filter :etl_clean_rule_id, as: :select, collection: -> { EtlCleanRule.all.map { |r| [r.name, r.id] } }
  filter :created_at, as: :date_range

  index do
    column :batch_id
    column I18n.t("admin.etl.clean_log.rule", default: "规则") do |log|
      log.etl_clean_rule&.name
    end
    column :source_table
    column :source_record_id
    column :field_name
    column :original_value
    column :cleaned_value
    column I18n.t("admin.etl.clean_log.action", default: "处理动作") do |log|
      status_tag log.action_taken, class: {
        'skipped' => :error, 'filled' => :warning,
        'transformed' => :ok, 'flagged' => :warning
      }[log.action_taken]
    end
    column :created_at
    actions defaults: false do |log|
      item I18n.t("active_admin.view"), admin_etl_clean_log_path(log)
    end
  end

  show do
    attributes_table do
      row :batch_id
      row :source_table
      row :source_record_id
      row :field_name
      row :original_value
      row :cleaned_value
      row :action_taken
      row :created_at
      row I18n.t("admin.etl.clean_log.rule", default: "触发规则") do |log|
        rule = log.etl_clean_rule
        link_to rule.name, admin_etl_clean_rule_path(rule) if rule
      end
    end
  end

  # Stats panel on index
  sidebar I18n.t("admin.etl.clean_log.stats", default: "清洗统计"), only: :index do
    top_fields = EtlCleanLog.group(:field_name).order('count_all DESC').limit(5).count
    ul do
      top_fields.each do |field, count|
        li "#{field}: #{count}"
      end
    end
  end
end
