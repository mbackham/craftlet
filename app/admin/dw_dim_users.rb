# frozen_string_literal: true

ActiveAdmin.register DwDimUser do
  menu parent: "etl_menu", priority: 4,
       label: proc { I18n.t("admin.etl.menu.dim_users", default: "用户画像") }

  actions :index, :show

  filter :nickname
  filter :email
  filter :rfm_segment, as: :select, collection: DwDimUser::RFM_SEGMENTS
  filter :user_level, as: :select, collection: DwDimUser::USER_LEVELS
  filter :status, as: :select, collection: %w[active disabled]
  filter :total_order_count_gteq, label: "最少订单数"
  filter :total_order_amount_gteq, label: "最低消费金额"
  filter :refund_rate_lteq, label: "退款率上限(%)"
  filter :profile_updated_at, as: :date_range

  index do
    column :source_user_id
    column :nickname
    column :email
    column :status do |u|
      status_tag u.status
    end
    column I18n.t("admin.etl.dim_user.rfm", default: "RFM分层") do |u|
      status_tag u.rfm_segment, class: rfm_tag_class(u.rfm_segment)
    end
    column :user_level
    column :total_order_count
    column I18n.t("admin.etl.dim_user.total_amount", default: "总消费") do |u|
      number_to_currency(u.total_order_amount, unit: "¥")
    end
    column I18n.t("admin.etl.dim_user.refund_rate", default: "退款率") do |u|
      "#{u.refund_rate}%"
    end
    column :last_order_at
    column :profile_updated_at
    actions defaults: false do |u|
      item I18n.t("active_admin.view"), admin_dw_dim_user_path(u)
    end
  end

  show do
    columns do
      column do
        panel I18n.t("admin.etl.dim_user.basic_info", default: "基本信息") do
          attributes_table_for resource do
            row :source_user_id
            row :email
            row :phone
            row :nickname
            row :status
            row :user_level
          end
        end
      end

      column do
        panel I18n.t("admin.etl.dim_user.order_stats", default: "消费统计") do
          attributes_table_for resource do
            row :total_order_count
            row(:total_order_amount) { |u| number_to_currency(u.total_order_amount, unit: "¥") }
            row(:avg_order_amount) { |u| number_to_currency(u.avg_order_amount, unit: "¥") }
            row :refund_count
            row(:refund_rate) { |u| "#{u.refund_rate}%" }
            row :coupon_used_count
            row(:coupon_total_discount) { |u| number_to_currency(u.coupon_total_discount, unit: "¥") }
          end
        end
      end
    end

    panel I18n.t("admin.etl.dim_user.rfm_profile", default: "RFM 画像") do
      attributes_table_for resource do
        row :rfm_segment
        row :first_order_at
        row :last_order_at
        row :days_since_last_order
        row(:tags) { |u| u.tags.join(", ") }
        row :profile_updated_at
      end
    end

    action_item :rebuild_profile, only: :show do
      link_to I18n.t("admin.etl.actions.rebuild_profile", default: "重建画像"),
              rebuild_profile_admin_dw_dim_user_path(resource),
              method: :post, class: "button"
    end
  end

  member_action :rebuild_profile, method: :post do
    Etl::Profiles::UserProfileBuilder.call(user_ids: [resource.source_user_id])
    redirect_to admin_dw_dim_user_path(resource), notice: I18n.t("admin.etl.notices.profile_rebuilt", default: "画像已重建")
  end

  action_item :rebuild_all_profiles, only: :index do
    link_to I18n.t("admin.etl.actions.rebuild_all_profiles", default: "全量重建用户画像"),
            rebuild_all_admin_dw_dim_users_path,
            method: :post,
            class: "button",
            data: { confirm: I18n.t("admin.etl.confirm.rebuild_all", default: "确认全量重建所有用户画像？") }
  end

  collection_action :rebuild_all, method: :post do
    Etl::ProfileRebuildJob.perform_later('users')
    redirect_to admin_dw_dim_users_path, notice: I18n.t("admin.etl.notices.rebuild_enqueued", default: "画像重建任务已加入队列")
  end

  # RFM segment sidebar stats
  sidebar I18n.t("admin.etl.dim_user.rfm_stats", default: "RFM 分层分布"), only: :index do
    stats = DwDimUser.group(:rfm_segment).count
    table do
      DwDimUser::RFM_SEGMENTS.each do |seg|
        tr do
          td seg
          td stats[seg].to_i
        end
      end
    end
  end

  controller do
    helper_method :rfm_tag_class

    def rfm_tag_class(segment)
      {
        'champion'           => :ok,
        'loyal_customer'     => :ok,
        'potential_loyalist' => :warning,
        'new_customer'       => :warning,
        'at_risk'            => :error,
        'lost'               => :error
      }[segment] || :default
    end
  end
end
