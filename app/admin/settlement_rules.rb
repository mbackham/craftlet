# frozen_string_literal: true

ActiveAdmin.register SettlementRule do
  menu parent: "settlement_menu", priority: 1, label: proc { I18n.t("admin.labels.settlement_rules") }

  actions :index, :show, :new, :create, :edit, :update, :destroy

  permit_params :merchant_profile_id, :cycle_type, :cycle_days,
                :deposit_deduction_rate, :penalty_rate, :min_settlement_amount, :is_active

  # === Scopes ===
  scope :all, default: true
  scope proc { I18n.t("admin.scopes.active_rules") }, :active_rules do |scope|
    scope.where(is_active: true)
  end
  scope proc { I18n.t("admin.scopes.global_default") }, :global_default do |scope|
    scope.where(merchant_profile_id: nil)
  end

  # === Filters ===
  filter :merchant_profile_id
  filter :cycle_type, as: :select, collection: SettlementRule::CYCLE_TYPES
  filter :is_active
  filter :created_at

  # === Index ===
  index do
    selectable_column
    id_column
    column I18n.t("admin.columns.merchant") do |rule|
      rule.merchant_name
    end
    column I18n.t("admin.columns.cycle_type"), :cycle_type
    column I18n.t("admin.columns.cycle_days"), :cycle_days
    column I18n.t("admin.columns.deposit_deduction_rate") do |rule|
      "#{(rule.deposit_deduction_rate * 100).round(2)}%"
    end
    column I18n.t("admin.columns.penalty_rate") do |rule|
      "#{(rule.penalty_rate * 100).round(2)}%"
    end
    column I18n.t("admin.columns.min_settlement_amount") do |rule|
      number_to_currency(rule.min_settlement_amount, unit: "¥")
    end
    column I18n.t("admin.columns.status") do |rule|
      status_tag(rule.is_active? ? "启用" : "停用", class: rule.is_active? ? "yes" : "error")
    end
    column I18n.t("admin.columns.created_time"), :created_at
    actions name: I18n.t("admin.columns.actions")
  end

  # === Show ===
  show do
    attributes_table do
      row(:id)
      row(I18n.t("admin.columns.merchant")) { |r| r.merchant_name }
      row(I18n.t("admin.columns.cycle_type")) { |r| r.cycle_type }
      row(I18n.t("admin.columns.cycle_days")) { |r| r.cycle_days }
      row(I18n.t("admin.columns.deposit_deduction_rate")) { |r| "#{(r.deposit_deduction_rate * 100).round(2)}%" }
      row(I18n.t("admin.columns.penalty_rate")) { |r| "#{(r.penalty_rate * 100).round(2)}%" }
      row(I18n.t("admin.columns.min_settlement_amount")) { |r| number_to_currency(r.min_settlement_amount, unit: "¥") }
      row(I18n.t("admin.columns.status")) do |r|
        status_tag(r.is_active? ? "启用" : "停用", class: r.is_active? ? "yes" : "error")
      end
      row(:created_at)
      row(:updated_at)
    end
  end

  # === Form ===
  form do |f|
    f.inputs I18n.t("admin.panels.settlement_rule_config") do
      f.input :merchant_profile_id, as: :select,
              collection: MerchantProfile.approved.map { |m| ["#{m.shop_name} (ID:#{m.id})", m.id] },
              include_blank: "全局默认规则（适用于所有未配置的商家）",
              hint: "留空表示全局默认规则"
      f.input :cycle_type, as: :select, collection: SettlementRule::CYCLE_TYPES
      f.input :cycle_days, hint: "T+N 天数"
      f.input :deposit_deduction_rate, hint: "0.0000 ~ 1.0000，例如 0.0500 = 5%"
      f.input :penalty_rate, hint: "0.0000 ~ 1.0000，例如 0.0100 = 1%"
      f.input :min_settlement_amount, hint: "低于此金额的结算将跳过"
      f.input :is_active
    end
    f.actions
  end
end
