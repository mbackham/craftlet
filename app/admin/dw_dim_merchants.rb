# frozen_string_literal: true

ActiveAdmin.register DwDimMerchant do
  menu parent: "etl_menu", priority: 5,
       label: proc { I18n.t("admin.etl.menu.dim_merchants", default: "商家画像") }

  actions :index, :show

  filter :shop_name
  filter :merchant_tier, as: :select, collection: DwDimMerchant::MERCHANT_TIERS
  filter :status, as: :select, collection: %w[approved pending suspended]
  filter :province, as: :string
  filter :city, as: :string
  filter :merchant_score_gteq, label: "最低评分"
  filter :total_gmv_gteq, label: "最低GMV"
  filter :refund_rate_lteq, label: "退款率上限(%)"
  filter :profile_updated_at, as: :date_range

  index do
    column :source_merchant_id
    column :shop_name
    column :status do |m|
      status_tag m.status
    end
    column I18n.t("admin.etl.dim_merchant.tier", default: "层级") do |m|
      status_tag m.merchant_tier, class: tier_tag_class(m.merchant_tier)
    end
    column I18n.t("admin.etl.dim_merchant.score", default: "评分"), :merchant_score
    column :province
    column :city
    column :total_order_count
    column I18n.t("admin.etl.dim_merchant.gmv", default: "GMV") do |m|
      number_to_currency(m.total_gmv, unit: "¥")
    end
    column I18n.t("admin.etl.dim_merchant.refund_rate", default: "退款率") do |m|
      color = m.refund_rate > 10 ? "color:red;" : "color:green;"
      content_tag(:span, "#{m.refund_rate}%", style: color)
    end
    column :profile_updated_at
    actions defaults: false do |m|
      item I18n.t("active_admin.view"), admin_dw_dim_merchant_path(m)
    end
  end

  show do
    columns do
      column do
        panel I18n.t("admin.etl.dim_merchant.basic_info", default: "基本信息") do
          attributes_table_for resource do
            row :source_merchant_id
            row :source_user_id
            row :shop_name
            row :status
            row :province
            row :city
          end
        end
      end

      column do
        panel I18n.t("admin.etl.dim_merchant.performance", default: "经营指标") do
          attributes_table_for resource do
            row :total_order_count
            row(:total_gmv) { |m| number_to_currency(m.total_gmv, unit: "¥") }
            row(:avg_order_amount) { |m| number_to_currency(m.avg_order_amount, unit: "¥") }
            row :refund_count
            row(:refund_rate) { |m| "#{m.refund_rate}%" }
            row :settlement_count
            row(:total_settled_amount) { |m| number_to_currency(m.total_settled_amount, unit: "¥") }
            row :risk_event_count
          end
        end
      end
    end

    panel I18n.t("admin.etl.dim_merchant.rating", default: "评分与分层") do
      attributes_table_for resource do
        row :merchant_tier
        row :merchant_score
        row(:tags) { |m| m.tags.join(", ") }
        row :profile_updated_at
      end
    end

    action_item :rebuild_profile, only: :show do
      link_to I18n.t("admin.etl.actions.rebuild_profile", default: "重建画像"),
              rebuild_profile_admin_dw_dim_merchant_path(resource),
              method: :post, class: "button"
    end
  end

  member_action :rebuild_profile, method: :post do
    Etl::Profiles::MerchantProfileBuilder.call(merchant_ids: [resource.source_merchant_id])
    redirect_to admin_dw_dim_merchant_path(resource), notice: I18n.t("admin.etl.notices.profile_rebuilt", default: "画像已重建")
  end

  action_item :rebuild_all_profiles, only: :index do
    link_to I18n.t("admin.etl.actions.rebuild_all_profiles", default: "全量重建商家画像"),
            rebuild_all_admin_dw_dim_merchants_path,
            method: :post,
            class: "button",
            data: { confirm: I18n.t("admin.etl.confirm.rebuild_all", default: "确认全量重建？") }
  end

  collection_action :rebuild_all, method: :post do
    Etl::ProfileRebuildJob.perform_later('merchants')
    redirect_to admin_dw_dim_merchants_path, notice: I18n.t("admin.etl.notices.rebuild_enqueued", default: "画像重建任务已加入队列")
  end

  # Tier distribution sidebar
  sidebar I18n.t("admin.etl.dim_merchant.tier_stats", default: "商家层级分布"), only: :index do
    stats = DwDimMerchant.group(:merchant_tier).count
    table do
      DwDimMerchant::MERCHANT_TIERS.each do |tier|
        tr do
          td tier
          td stats[tier].to_i
        end
      end
    end
  end

  controller do
    helper_method :tier_tag_class

    def tier_tag_class(tier)
      { 'platinum' => :ok, 'gold' => :ok, 'silver' => :warning, 'standard' => :default }[tier] || :default
    end
  end
end
