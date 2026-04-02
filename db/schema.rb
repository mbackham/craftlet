# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_04_02_100007) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "ab_tests", force: :cascade do |t|
    t.string "name", null: false, comment: "实验名称"
    t.string "test_key", null: false, comment: "唯一标识 key"
    t.text "description", comment: "实验描述"
    t.string "status", default: "draft", null: false, comment: "draft / running / paused / completed"
    t.jsonb "variants", default: [], null: false, comment: "变体配置 [{ \"name\": \"A\", \"weight\": 50, \"config\": {} }]"
    t.integer "traffic_percentage", default: 100, comment: "总流量百分比"
    t.datetime "start_at", comment: "开始时间"
    t.datetime "end_at", comment: "结束时间"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_ab_tests_on_status"
    t.index ["test_key"], name: "index_ab_tests_on_test_key", unique: true
  end

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "author_type"
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_permissions", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_admin_permissions_on_code", unique: true
    t.index ["name"], name: "index_admin_permissions_on_name", unique: true
  end

  create_table "admin_role_permissions", force: :cascade do |t|
    t.bigint "admin_role_id", null: false
    t.bigint "admin_permission_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_permission_id"], name: "index_admin_role_permissions_on_admin_permission_id"
    t.index ["admin_role_id", "admin_permission_id"], name: "index_admin_role_permissions_on_role_and_permission", unique: true
    t.index ["admin_role_id"], name: "index_admin_role_permissions_on_admin_role_id"
  end

  create_table "admin_roles", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_admin_roles_on_code", unique: true
    t.index ["name"], name: "index_admin_roles_on_name", unique: true
  end

  create_table "admin_user_roles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "admin_role_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_role_id"], name: "index_admin_user_roles_on_admin_role_id"
    t.index ["user_id", "admin_role_id"], name: "index_admin_user_roles_on_user_id_and_admin_role_id", unique: true
    t.index ["user_id"], name: "index_admin_user_roles_on_user_id"
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "admin", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_admin_users_on_role"
    t.index ["unlock_token"], name: "index_admin_users_on_unlock_token", unique: true
  end

  create_table "announcements", force: :cascade do |t|
    t.jsonb "title", default: {}, null: false, comment: "多语言标题"
    t.jsonb "content", default: {}, null: false, comment: "多语言内容"
    t.string "announcement_type", default: "info", null: false, comment: "info / warning / maintenance"
    t.string "status", default: "draft", null: false, comment: "draft / published / archived"
    t.boolean "is_pinned", default: false, comment: "是否置顶"
    t.datetime "publish_at", comment: "定时发布时间"
    t.datetime "expire_at", comment: "过期时间"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["announcement_type"], name: "index_announcements_on_announcement_type"
    t.index ["is_pinned"], name: "index_announcements_on_is_pinned"
    t.index ["publish_at"], name: "index_announcements_on_publish_at"
    t.index ["status"], name: "index_announcements_on_status"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "actor_type", null: false
    t.uuid "actor_id", null: false
    t.string "action", null: false
    t.string "subject_type", null: false
    t.uuid "subject_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "target_type"
    t.bigint "target_id"
    t.jsonb "before"
    t.jsonb "after"
    t.string "request_id"
    t.string "ip"
    t.string "user_agent"
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["actor_type", "actor_id"], name: "index_audit_logs_on_actor_type_and_actor_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["subject_type", "subject_id"], name: "index_audit_logs_on_subject_type_and_subject_id"
    t.index ["target_type", "target_id"], name: "index_audit_logs_on_target_type_and_target_id"
  end

  create_table "bank_statements", force: :cascade do |t|
    t.string "channel"
    t.date "statement_date"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "banners", force: :cascade do |t|
    t.jsonb "title", default: {}, null: false, comment: "多语言标题 { zh-CN: ..., en: ... }"
    t.string "link_url", comment: "点击跳转链接"
    t.string "image_key", comment: "OSS 图片 Key"
    t.integer "position", default: 0, comment: "排序位置"
    t.string "placement", default: "home", null: false, comment: "展示位置: home / category / detail"
    t.string "status", default: "draft", null: false, comment: "draft / active / inactive"
    t.datetime "start_at", comment: "定时上线"
    t.datetime "end_at", comment: "定时下线"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["placement"], name: "index_banners_on_placement"
    t.index ["position"], name: "index_banners_on_position"
    t.index ["status"], name: "index_banners_on_status"
  end

  create_table "bids", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.uuid "bidder_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bidder_id"], name: "index_bids_on_bidder_id"
    t.index ["order_id"], name: "index_bids_on_order_id"
    t.index ["status"], name: "index_bids_on_status"
  end

  create_table "coupon_budget_alerts", force: :cascade do |t|
    t.bigint "coupon_template_id", null: false, comment: "关联模板"
    t.string "alert_type", null: false, comment: "quota_threshold / budget_threshold / quota_exhausted / budget_exhausted"
    t.decimal "current_ratio", precision: 5, scale: 4, comment: "触发时的使用比例"
    t.string "status", default: "pending", null: false, comment: "pending / acknowledged"
    t.bigint "acknowledged_by_id", comment: "处理人 AdminUser ID"
    t.datetime "acknowledged_at", comment: "处理时间"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_type"], name: "index_coupon_budget_alerts_on_alert_type"
    t.index ["coupon_template_id"], name: "index_coupon_budget_alerts_on_coupon_template_id"
    t.index ["status"], name: "index_coupon_budget_alerts_on_status"
  end

  create_table "coupon_templates", force: :cascade do |t|
    t.string "name", null: false, comment: "模板名称"
    t.string "coupon_type", null: false, comment: "类型: fixed_amount / discount / redeem_code"
    t.decimal "face_value", precision: 12, scale: 2, comment: "面值（满减：减少金额；折扣：折扣率 0-1；兑换码：商品价值）"
    t.decimal "min_order_amount", precision: 12, scale: 2, default: "0.0", comment: "最低使用金额，0 表示无限制"
    t.string "status", default: "draft", null: false, comment: "draft / active / inactive"
    t.jsonb "category_ids", default: [], null: false, comment: "限制品类 ID 列表，空表示不限"
    t.jsonb "merchant_ids", default: [], null: false, comment: "限制商家 ID 列表，空表示不限"
    t.datetime "valid_from", comment: "优惠券有效期开始时间"
    t.datetime "valid_until", comment: "优惠券有效期结束时间"
    t.integer "valid_days", comment: "领取后 N 天内有效，与 valid_from/until 二选一"
    t.integer "per_user_limit", default: 1, comment: "每人最多领取张数，0 表示不限"
    t.jsonb "grant_rules", default: {}, null: false, comment: "发放规则: { new_user: true, birthday: true, min_level: 2 }"
    t.integer "total_quota", comment: "总发放量，nil 表示不限"
    t.integer "issued_count", default: 0, null: false, comment: "已发放数量"
    t.decimal "budget_amount", precision: 14, scale: 2, comment: "预算总额，nil 表示不限"
    t.decimal "used_amount", precision: 14, scale: 2, default: "0.0", null: false, comment: "已使用金额"
    t.decimal "budget_alert_threshold", precision: 5, scale: 2, default: "0.8", comment: "预算告警阈值（比例），0.8 = 80%"
    t.text "description", comment: "备注说明"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coupon_type"], name: "index_coupon_templates_on_coupon_type"
    t.index ["status"], name: "index_coupon_templates_on_status"
  end

  create_table "coupons", force: :cascade do |t|
    t.bigint "coupon_template_id", null: false, comment: "关联的优惠券模板"
    t.bigint "user_id", null: false, comment: "持有用户 ID"
    t.string "code", null: false, comment: "优惠券码（兑换码类型用随机字符串）"
    t.string "status", default: "unused", null: false, comment: "unused / used / expired / locked"
    t.string "grant_type", default: "manual", null: false, comment: "发放来源: manual / new_user / birthday / level_up / redeem"
    t.datetime "granted_at", null: false, comment: "发放时间"
    t.datetime "expires_at", comment: "过期时间（由模板计算得出）"
    t.datetime "used_at", comment: "使用时间"
    t.bigint "order_id", comment: "使用时关联的订单 ID"
    t.decimal "discount_amount", precision: 12, scale: 2, comment: "实际抵扣金额"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_coupons_on_code", unique: true
    t.index ["coupon_template_id"], name: "index_coupons_on_coupon_template_id"
    t.index ["order_id"], name: "index_coupons_on_order_id"
    t.index ["status"], name: "index_coupons_on_status"
    t.index ["user_id", "coupon_template_id"], name: "index_coupons_on_user_and_template"
    t.index ["user_id"], name: "index_coupons_on_user_id"
  end

  create_table "dw_dim_merchants", force: :cascade do |t|
    t.bigint "source_merchant_id", null: false
    t.bigint "source_user_id"
    t.string "shop_name"
    t.string "status"
    t.string "province"
    t.string "city"
    t.integer "total_order_count", default: 0
    t.decimal "total_gmv", precision: 14, scale: 2, default: "0.0"
    t.decimal "avg_order_amount", precision: 12, scale: 2, default: "0.0"
    t.integer "refund_count", default: 0
    t.decimal "refund_rate", precision: 5, scale: 2, default: "0.0"
    t.integer "settlement_count", default: 0
    t.decimal "total_settled_amount", precision: 14, scale: 2, default: "0.0"
    t.integer "risk_event_count", default: 0
    t.string "merchant_tier", default: "standard"
    t.decimal "merchant_score", precision: 5, scale: 2, default: "0.0"
    t.jsonb "tags", default: []
    t.jsonb "extra", default: {}
    t.datetime "profile_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["merchant_score"], name: "index_dw_dim_merchants_on_merchant_score"
    t.index ["merchant_tier"], name: "index_dw_dim_merchants_on_merchant_tier"
    t.index ["source_merchant_id"], name: "index_dw_dim_merchants_on_source_merchant_id", unique: true
  end

  create_table "dw_dim_time", force: :cascade do |t|
    t.date "date_value", null: false
    t.integer "year"
    t.integer "quarter"
    t.integer "month"
    t.integer "week_of_year"
    t.integer "day_of_week"
    t.boolean "is_weekend"
    t.boolean "is_holiday", default: false
    t.string "holiday_name"
    t.index ["date_value"], name: "index_dw_dim_time_on_date_value", unique: true
  end

  create_table "dw_dim_users", force: :cascade do |t|
    t.bigint "source_user_id", null: false
    t.string "email"
    t.string "phone"
    t.string "nickname"
    t.string "status"
    t.string "user_level", default: "normal"
    t.string "registration_channel"
    t.integer "total_order_count", default: 0
    t.decimal "total_order_amount", precision: 14, scale: 2, default: "0.0"
    t.decimal "avg_order_amount", precision: 12, scale: 2, default: "0.0"
    t.integer "refund_count", default: 0
    t.decimal "refund_rate", precision: 5, scale: 2, default: "0.0"
    t.integer "coupon_used_count", default: 0
    t.decimal "coupon_total_discount", precision: 12, scale: 2, default: "0.0"
    t.datetime "first_order_at"
    t.datetime "last_order_at"
    t.integer "days_since_last_order"
    t.string "rfm_segment"
    t.jsonb "tags", default: []
    t.jsonb "extra", default: {}
    t.datetime "profile_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["rfm_segment"], name: "index_dw_dim_users_on_rfm_segment"
    t.index ["source_user_id"], name: "index_dw_dim_users_on_source_user_id", unique: true
    t.index ["user_level"], name: "index_dw_dim_users_on_user_level"
  end

  create_table "dw_fact_coupons", force: :cascade do |t|
    t.bigint "source_id", null: false
    t.bigint "user_id"
    t.bigint "template_id"
    t.decimal "discount_amount", precision: 12, scale: 2
    t.datetime "used_at"
    t.datetime "synced_at"
    t.string "etl_batch_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["etl_batch_id"], name: "index_dw_fact_coupons_on_etl_batch_id"
    t.index ["source_id"], name: "index_dw_fact_coupons_on_source_id", unique: true
    t.index ["user_id"], name: "index_dw_fact_coupons_on_user_id"
  end

  create_table "dw_fact_orders", force: :cascade do |t|
    t.bigint "source_id", null: false
    t.string "order_no"
    t.string "customer_id"
    t.string "merchant_id"
    t.string "status"
    t.decimal "total_amount", precision: 12, scale: 2
    t.string "currency"
    t.datetime "paid_at"
    t.datetime "completed_at"
    t.datetime "canceled_at"
    t.bigint "dim_time_id"
    t.datetime "synced_at"
    t.string "etl_batch_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["etl_batch_id"], name: "index_dw_fact_orders_on_etl_batch_id"
    t.index ["paid_at"], name: "index_dw_fact_orders_on_paid_at"
    t.index ["source_id"], name: "index_dw_fact_orders_on_source_id", unique: true
    t.index ["status"], name: "index_dw_fact_orders_on_status"
  end

  create_table "dw_fact_payments", force: :cascade do |t|
    t.bigint "source_id", null: false
    t.bigint "order_source_id"
    t.string "channel"
    t.decimal "amount", precision: 12, scale: 2
    t.string "status"
    t.datetime "paid_at"
    t.datetime "synced_at"
    t.string "etl_batch_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["etl_batch_id"], name: "index_dw_fact_payments_on_etl_batch_id"
    t.index ["order_source_id"], name: "index_dw_fact_payments_on_order_source_id"
    t.index ["source_id"], name: "index_dw_fact_payments_on_source_id", unique: true
  end

  create_table "dw_fact_refunds", force: :cascade do |t|
    t.bigint "source_id", null: false
    t.bigint "order_source_id"
    t.decimal "amount", precision: 12, scale: 2
    t.string "reason"
    t.string "status"
    t.datetime "succeeded_at"
    t.datetime "synced_at"
    t.string "etl_batch_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["etl_batch_id"], name: "index_dw_fact_refunds_on_etl_batch_id"
    t.index ["order_source_id"], name: "index_dw_fact_refunds_on_order_source_id"
    t.index ["source_id"], name: "index_dw_fact_refunds_on_source_id", unique: true
  end

  create_table "dw_fact_settlements", force: :cascade do |t|
    t.bigint "source_id", null: false
    t.bigint "merchant_source_id"
    t.decimal "net_amount", precision: 12, scale: 2
    t.string "status"
    t.date "period_start"
    t.date "period_end"
    t.datetime "synced_at"
    t.string "etl_batch_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["etl_batch_id"], name: "index_dw_fact_settlements_on_etl_batch_id"
    t.index ["merchant_source_id"], name: "index_dw_fact_settlements_on_merchant_source_id"
    t.index ["source_id"], name: "index_dw_fact_settlements_on_source_id", unique: true
  end

  create_table "elements", force: :cascade do |t|
    t.string "name", null: false
    t.string "category"
    t.string "status", default: "draft", null: false
    t.decimal "price", precision: 10, scale: 2
    t.string "oss_key"
    t.string "thumbnail_key"
    t.text "description"
    t.datetime "shelved_at"
    t.datetime "unshelved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_elements_on_category"
    t.index ["created_at"], name: "index_elements_on_created_at"
    t.index ["status"], name: "index_elements_on_status"
  end

  create_table "etl_clean_logs", force: :cascade do |t|
    t.bigint "etl_clean_rule_id", null: false
    t.string "batch_id", null: false
    t.string "source_table", null: false
    t.bigint "source_record_id", null: false
    t.string "field_name", null: false
    t.text "original_value"
    t.text "cleaned_value"
    t.string "action_taken"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["batch_id"], name: "index_etl_clean_logs_on_batch_id"
    t.index ["etl_clean_rule_id"], name: "index_etl_clean_logs_on_etl_clean_rule_id"
    t.index ["source_record_id"], name: "index_etl_clean_logs_on_source_record_id"
    t.index ["source_table"], name: "index_etl_clean_logs_on_source_table"
  end

  create_table "etl_clean_rules", force: :cascade do |t|
    t.string "name", null: false
    t.string "source_table", null: false
    t.string "target_field", null: false
    t.string "rule_type", null: false
    t.string "action", default: "skip"
    t.jsonb "params", default: {}, null: false
    t.integer "priority", default: 0
    t.boolean "is_active", default: true
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_etl_clean_rules_on_is_active"
    t.index ["rule_type"], name: "index_etl_clean_rules_on_rule_type"
    t.index ["source_table"], name: "index_etl_clean_rules_on_source_table"
  end

  create_table "etl_lineage_edges", force: :cascade do |t|
    t.bigint "upstream_id", null: false
    t.bigint "downstream_id", null: false
    t.string "edge_type", default: "etl"
    t.string "transform_logic"
    t.jsonb "field_mapping", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["downstream_id"], name: "index_etl_lineage_edges_on_downstream_id"
    t.index ["upstream_id", "downstream_id"], name: "index_etl_lineage_edges_on_upstream_id_and_downstream_id", unique: true
    t.index ["upstream_id"], name: "index_etl_lineage_edges_on_upstream_id"
  end

  create_table "etl_lineage_nodes", force: :cascade do |t|
    t.string "node_type", null: false
    t.string "name", null: false
    t.string "schema_name"
    t.text "description"
    t.jsonb "metadata", default: {}
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["node_type", "name"], name: "index_etl_lineage_nodes_on_node_type_and_name", unique: true
  end

  create_table "etl_sync_logs", force: :cascade do |t|
    t.string "source_table", null: false
    t.string "target_table", null: false
    t.string "sync_type", default: "incremental"
    t.string "status", default: "running"
    t.integer "extracted_count", default: 0
    t.integer "loaded_count", default: 0
    t.integer "cleaned_count", default: 0
    t.integer "error_count", default: 0
    t.datetime "started_at"
    t.datetime "completed_at"
    t.text "error_message"
    t.string "batch_id", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["batch_id"], name: "index_etl_sync_logs_on_batch_id"
    t.index ["source_table"], name: "index_etl_sync_logs_on_source_table"
    t.index ["started_at"], name: "index_etl_sync_logs_on_started_at"
    t.index ["status"], name: "index_etl_sync_logs_on_status"
  end

  create_table "faq_categories", force: :cascade do |t|
    t.jsonb "name", default: {}, null: false
    t.string "slug"
    t.integer "sort", default: 0
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_faq_categories_on_slug", unique: true
  end

  create_table "faqs", force: :cascade do |t|
    t.jsonb "question", default: {}, null: false
    t.jsonb "answer", default: {}, null: false
    t.bigint "faq_category_id"
    t.integer "sort", default: 0
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["faq_category_id"], name: "index_faqs_on_faq_category_id"
  end

  create_table "feedbacks", force: :cascade do |t|
    t.string "tracking_number", null: false, comment: "追踪号"
    t.string "feedback_type", default: "other", null: false, comment: "反馈类型"
    t.string "subject", null: false, comment: "标题"
    t.text "content", null: false, comment: "内容"
    t.string "status", default: "pending", null: false, comment: "状态"
    t.string "priority", default: "medium", comment: "优先级"
    t.bigint "user_id", comment: "用户ID"
    t.string "user_type", comment: "用户类型"
    t.string "submitter_name", comment: "提交者姓名"
    t.string "submitter_email", null: false, comment: "提交者邮箱"
    t.string "submitter_phone", comment: "提交者电话"
    t.string "page_url", comment: "页面URL"
    t.text "user_agent", comment: "浏览器信息"
    t.inet "ip_address", comment: "IP地址"
    t.bigint "admin_user_id", comment: "处理人ID"
    t.text "admin_note", comment: "内部备注"
    t.datetime "resolved_at", comment: "解决时间"
    t.text "response", comment: "回复内容"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_user_id"], name: "index_feedbacks_on_admin_user_id"
    t.index ["created_at"], name: "index_feedbacks_on_created_at"
    t.index ["feedback_type"], name: "index_feedbacks_on_feedback_type"
    t.index ["status"], name: "index_feedbacks_on_status"
    t.index ["submitter_email"], name: "index_feedbacks_on_submitter_email"
    t.index ["tracking_number"], name: "index_feedbacks_on_tracking_number", unique: true
    t.index ["user_id"], name: "index_feedbacks_on_user_id"
  end

  create_table "fund_alerts", force: :cascade do |t|
    t.string "alert_type", null: false
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.decimal "threshold", precision: 12, scale: 2, null: false
    t.string "status", default: "pending", null: false
    t.bigint "handler_admin_id"
    t.text "note"
    t.datetime "acknowledged_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_type"], name: "index_fund_alerts_on_alert_type"
    t.index ["created_at"], name: "index_fund_alerts_on_created_at"
    t.index ["status"], name: "index_fund_alerts_on_status"
    t.index ["subject_type", "subject_id"], name: "index_fund_alerts_on_subject_type_and_subject_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.string "invoice_no", null: false, comment: "发票编号"
    t.bigint "settlement_id", null: false
    t.bigint "merchant_profile_id", null: false
    t.string "invoice_type", default: "normal", null: false, comment: "normal / special"
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "status", default: "requested", null: false, comment: "发票状态"
    t.string "title", comment: "发票抬头"
    t.string "tax_no", comment: "纳税人识别号"
    t.string "tracking_no", comment: "快递单号"
    t.datetime "shipped_at"
    t.datetime "received_at"
    t.string "rejected_reason", limit: 500
    t.datetime "requested_at"
    t.datetime "issued_at"
    t.bigint "issued_by", comment: "开票人 admin_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_no"], name: "index_invoices_on_invoice_no", unique: true
    t.index ["merchant_profile_id"], name: "index_invoices_on_merchant_profile_id"
    t.index ["settlement_id"], name: "index_invoices_on_settlement_id"
    t.index ["status"], name: "index_invoices_on_status"
  end

  create_table "merchant_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "shop_name", null: false
    t.string "status", default: "pending", null: false
    t.string "address_province"
    t.string "address_city"
    t.string "address_district"
    t.string "address_detail"
    t.string "license_file_key"
    t.string "idcard_front_key"
    t.string "idcard_back_key"
    t.text "bank_account_name_ciphertext"
    t.text "bank_account_no_ciphertext"
    t.string "bank_account_no_bidx"
    t.string "bank_name"
    t.string "bank_branch"
    t.decimal "deposit_amount", precision: 12, scale: 2
    t.datetime "approved_at"
    t.uuid "approved_by_admin_id"
    t.datetime "rejected_at"
    t.uuid "rejected_by_admin_id"
    t.text "reject_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_admin_id"], name: "index_merchant_profiles_on_approved_by_admin_id"
    t.index ["bank_account_no_bidx"], name: "index_merchant_profiles_on_bank_account_no_bidx", unique: true
    t.index ["rejected_by_admin_id"], name: "index_merchant_profiles_on_rejected_by_admin_id"
    t.index ["status"], name: "index_merchant_profiles_on_status"
    t.index ["user_id"], name: "index_merchant_profiles_on_user_id", unique: true
  end

  create_table "merchant_review_logs", force: :cascade do |t|
    t.bigint "merchant_profile_id", null: false
    t.string "action", null: false
    t.uuid "operator_admin_id", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_merchant_review_logs_on_action"
    t.index ["merchant_profile_id"], name: "index_merchant_review_logs_on_merchant_profile_id"
    t.index ["operator_admin_id"], name: "index_merchant_review_logs_on_operator_admin_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "name"
    t.decimal "unit_price", precision: 10, scale: 2
    t.integer "quantity", default: 1
    t.decimal "subtotal", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_type", "item_id"], name: "index_order_items_on_item_type_and_item_id"
    t.index ["order_id"], name: "index_order_items_on_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.string "order_no", null: false
    t.uuid "customer_id", null: false
    t.uuid "merchant_id", null: false
    t.string "status", default: "pending", null: false
    t.decimal "total_amount", precision: 12, scale: 2, null: false
    t.string "currency", default: "CNY", null: false
    t.string "cancel_reason"
    t.string "canceled_by_type"
    t.uuid "canceled_by_id"
    t.datetime "paid_at"
    t.datetime "accepted_at"
    t.datetime "producing_at"
    t.datetime "delivered_at"
    t.datetime "completed_at"
    t.datetime "canceled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["merchant_id"], name: "index_orders_on_merchant_id"
    t.index ["order_no"], name: "index_orders_on_order_no", unique: true
    t.index ["status"], name: "index_orders_on_status"
  end

  create_table "outbox_events", force: :cascade do |t|
    t.string "event_type", null: false
    t.string "aggregate_type", null: false
    t.uuid "aggregate_id", null: false
    t.jsonb "payload", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.integer "retry_count", default: 0, null: false
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["aggregate_type", "aggregate_id"], name: "index_outbox_events_on_aggregate_type_and_aggregate_id"
    t.index ["event_type"], name: "index_outbox_events_on_event_type"
    t.index ["status"], name: "index_outbox_events_on_status"
  end

  create_table "payment_callbacks", force: :cascade do |t|
    t.bigint "payment_id", null: false
    t.string "channel", null: false
    t.string "provider_trade_no", null: false
    t.jsonb "headers", default: {}, null: false
    t.jsonb "payload", default: {}, null: false
    t.boolean "verified", default: false, null: false
    t.string "process_status", default: "pending", null: false
    t.text "process_error"
    t.datetime "received_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel", "provider_trade_no"], name: "index_payment_callbacks_on_channel_and_provider_trade_no"
    t.index ["payment_id"], name: "index_payment_callbacks_on_payment_id"
    t.index ["process_status"], name: "index_payment_callbacks_on_process_status"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "channel", null: false
    t.string "status", default: "init", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "currency", default: "CNY", null: false
    t.string "provider_trade_no"
    t.string "idempotency_key", null: false
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "request_payload", default: {}, null: false
    t.jsonb "response_payload", default: {}, null: false
    t.jsonb "notify_payload", default: {}, null: false
    t.string "failure_reason", limit: 500
    t.index ["idempotency_key"], name: "index_payments_on_idempotency_key", unique: true
    t.index ["order_id"], name: "index_payments_on_order_id"
    t.index ["provider_trade_no"], name: "index_payments_on_provider_trade_no", unique: true
    t.index ["status"], name: "index_payments_on_status"
  end

  create_table "reconciliation_batches", force: :cascade do |t|
    t.date "target_date"
    t.string "status"
    t.string "channel"
    t.integer "total_count", default: 0
    t.integer "matched_count", default: 0
    t.integer "mismatched_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "reconciliation_details", force: :cascade do |t|
    t.bigint "reconciliation_batch_id", null: false
    t.string "transaction_no"
    t.string "order_no"
    t.string "reconciliation_type"
    t.decimal "system_amount", precision: 10, scale: 2
    t.decimal "statement_amount", precision: 10, scale: 2
    t.string "match_status"
    t.string "process_status"
    t.integer "handler_admin_id"
    t.text "adjustment_reason"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_no"], name: "index_reconciliation_details_on_order_no"
    t.index ["reconciliation_batch_id"], name: "index_reconciliation_details_on_reconciliation_batch_id"
    t.index ["transaction_no"], name: "index_reconciliation_details_on_transaction_no"
  end

  create_table "refunds", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "payment_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "reason"
    t.string "status", default: "init", null: false
    t.string "provider_refund_no"
    t.string "idempotency_key", null: false
    t.string "requested_by_type"
    t.uuid "requested_by_id"
    t.datetime "succeeded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "request_payload", default: {}, null: false
    t.jsonb "response_payload", default: {}, null: false
    t.jsonb "notify_payload", default: {}, null: false
    t.string "failure_reason", limit: 500
    t.index ["idempotency_key"], name: "index_refunds_on_idempotency_key", unique: true
    t.index ["order_id"], name: "index_refunds_on_order_id"
    t.index ["payment_id"], name: "index_refunds_on_payment_id"
    t.index ["provider_refund_no"], name: "index_refunds_on_provider_refund_no", unique: true
    t.index ["status"], name: "index_refunds_on_status"
  end

  create_table "risk_events", force: :cascade do |t|
    t.bigint "risk_rule_id", null: false
    t.string "status", default: "pending", null: false
    t.uuid "subject_id", null: false
    t.string "subject_type", default: "User"
    t.string "trigger_source"
    t.jsonb "context", default: {}, null: false
    t.text "resolution_note"
    t.uuid "resolved_by_id"
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["risk_rule_id", "subject_id"], name: "index_risk_events_on_risk_rule_id_and_subject_id"
    t.index ["risk_rule_id"], name: "index_risk_events_on_risk_rule_id"
    t.index ["status"], name: "index_risk_events_on_status"
    t.index ["subject_id"], name: "index_risk_events_on_subject_id"
    t.index ["trigger_source"], name: "index_risk_events_on_trigger_source"
  end

  create_table "risk_rules", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.text "description"
    t.string "category", default: "general"
    t.string "severity", default: "medium"
    t.jsonb "params", default: {}, null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_risk_rules_on_category"
    t.index ["code"], name: "index_risk_rules_on_code", unique: true
    t.index ["enabled"], name: "index_risk_rules_on_enabled"
  end

  create_table "roles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "role_type", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_roles_on_is_active"
    t.index ["role_type"], name: "index_roles_on_role_type"
    t.index ["user_id", "role_type"], name: "index_roles_on_user_id_and_role_type", unique: true
    t.index ["user_id"], name: "index_roles_on_user_id"
  end

  create_table "settlement_exceptions", force: :cascade do |t|
    t.bigint "settlement_id", null: false
    t.string "exception_type", null: false, comment: "payout_failed / amount_mismatch / merchant_frozen"
    t.text "description"
    t.string "status", default: "pending", null: false, comment: "pending / processing / resolved / ignored"
    t.bigint "resolved_by", comment: "处理人 admin_user_id"
    t.datetime "resolved_at"
    t.text "resolution_note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exception_type"], name: "index_settlement_exceptions_on_exception_type"
    t.index ["settlement_id"], name: "index_settlement_exceptions_on_settlement_id"
    t.index ["status"], name: "index_settlement_exceptions_on_status"
  end

  create_table "settlement_items", force: :cascade do |t|
    t.bigint "settlement_id", null: false
    t.bigint "order_id", null: false
    t.decimal "order_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "refund_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "net_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_settlement_items_on_order_id"
    t.index ["settlement_id", "order_id"], name: "idx_settlement_items_settlement_order", unique: true
    t.index ["settlement_id"], name: "index_settlement_items_on_settlement_id"
  end

  create_table "settlement_rules", force: :cascade do |t|
    t.bigint "merchant_profile_id", comment: "关联商家（null=全局默认）"
    t.string "cycle_type", default: "T+7", null: false, comment: "结算周期类型"
    t.integer "cycle_days", default: 7, null: false, comment: "T+N 天数"
    t.decimal "deposit_deduction_rate", precision: 5, scale: 4, default: "0.0", null: false, comment: "保证金扣除比例"
    t.decimal "penalty_rate", precision: 5, scale: 4, default: "0.0", null: false, comment: "违约金比例"
    t.decimal "min_settlement_amount", precision: 12, scale: 2, default: "0.0", null: false, comment: "最低结算金额"
    t.boolean "is_active", default: true, null: false, comment: "是否启用"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_settlement_rules_on_is_active"
    t.index ["merchant_profile_id", "is_active"], name: "idx_settlement_rules_merchant_active"
    t.index ["merchant_profile_id"], name: "index_settlement_rules_on_merchant_profile_id"
  end

  create_table "settlements", force: :cascade do |t|
    t.string "settlement_no", null: false, comment: "结算单号"
    t.bigint "merchant_profile_id", null: false, comment: "关联商家"
    t.date "period_start", null: false, comment: "结算周期起始"
    t.date "period_end", null: false, comment: "结算周期结束"
    t.decimal "total_order_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total_refund_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "deposit_deduction", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "penalty_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "net_amount", precision: 12, scale: 2, default: "0.0", null: false, comment: "实际结算金额"
    t.string "status", default: "pending_review", null: false, comment: "状态"
    t.bigint "approved_by", comment: "审批人 admin_user_id"
    t.datetime "approved_at"
    t.bigint "paid_out_by", comment: "出纳 admin_user_id"
    t.datetime "paid_out_at"
    t.datetime "confirmed_at", comment: "到账确认时间"
    t.string "payout_reference", comment: "打款凭证号"
    t.string "failure_reason", limit: 500
    t.string "frozen_reason", limit: 500
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["merchant_profile_id", "period_start", "period_end"], name: "idx_settlements_merchant_period", unique: true
    t.index ["merchant_profile_id"], name: "index_settlements_on_merchant_profile_id"
    t.index ["settlement_no"], name: "index_settlements_on_settlement_no", unique: true
    t.index ["status"], name: "index_settlements_on_status"
  end

  create_table "ticket_attachments", force: :cascade do |t|
    t.bigint "ticket_message_id", null: false
    t.string "file_name", null: false
    t.string "file_type"
    t.integer "file_size"
    t.string "oss_key"
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ticket_message_id"], name: "index_ticket_attachments_on_ticket_message_id"
  end

  create_table "ticket_messages", force: :cascade do |t|
    t.bigint "ticket_id", null: false
    t.uuid "sender_id", null: false
    t.string "sender_type", default: "User"
    t.text "content", null: false
    t.boolean "internal", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sender_id"], name: "index_ticket_messages_on_sender_id"
    t.index ["ticket_id"], name: "index_ticket_messages_on_ticket_id"
  end

  create_table "tickets", force: :cascade do |t|
    t.string "ticket_no", null: false
    t.string "subject", null: false
    t.text "description"
    t.string "category", default: "general"
    t.string "priority", default: "normal"
    t.string "status", default: "open", null: false
    t.uuid "creator_id", null: false
    t.string "creator_type", default: "User"
    t.uuid "assignee_id"
    t.uuid "order_id"
    t.datetime "assigned_at"
    t.datetime "resolved_at"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_tickets_on_assignee_id"
    t.index ["category"], name: "index_tickets_on_category"
    t.index ["creator_id"], name: "index_tickets_on_creator_id"
    t.index ["order_id"], name: "index_tickets_on_order_id"
    t.index ["priority"], name: "index_tickets_on_priority"
    t.index ["status"], name: "index_tickets_on_status"
    t.index ["ticket_no"], name: "index_tickets_on_ticket_no", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone"
    t.string "nickname"
    t.string "avatar_key"
    t.string "status", default: "active", null: false
    t.datetime "disabled_at"
    t.string "disabled_reason"
    t.string "jti", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.index ["disabled_at"], name: "index_users_on_disabled_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["phone"], name: "index_users_on_phone", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["status"], name: "index_users_on_status"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admin_role_permissions", "admin_permissions"
  add_foreign_key "admin_role_permissions", "admin_roles"
  add_foreign_key "admin_user_roles", "admin_roles"
  add_foreign_key "admin_user_roles", "admin_users", column: "user_id"
  add_foreign_key "bids", "orders"
  add_foreign_key "coupon_budget_alerts", "coupon_templates"
  add_foreign_key "coupons", "coupon_templates"
  add_foreign_key "etl_clean_logs", "etl_clean_rules"
  add_foreign_key "etl_lineage_edges", "etl_lineage_nodes", column: "downstream_id"
  add_foreign_key "etl_lineage_edges", "etl_lineage_nodes", column: "upstream_id"
  add_foreign_key "faqs", "faq_categories"
  add_foreign_key "feedbacks", "admin_users", on_delete: :nullify
  add_foreign_key "feedbacks", "users", on_delete: :nullify
  add_foreign_key "invoices", "merchant_profiles"
  add_foreign_key "invoices", "settlements"
  add_foreign_key "merchant_profiles", "users"
  add_foreign_key "merchant_review_logs", "merchant_profiles"
  add_foreign_key "order_items", "orders"
  add_foreign_key "payment_callbacks", "payments"
  add_foreign_key "payments", "orders"
  add_foreign_key "reconciliation_details", "reconciliation_batches"
  add_foreign_key "refunds", "orders"
  add_foreign_key "refunds", "payments"
  add_foreign_key "risk_events", "risk_rules"
  add_foreign_key "roles", "users"
  add_foreign_key "settlement_exceptions", "settlements"
  add_foreign_key "settlement_items", "orders"
  add_foreign_key "settlement_items", "settlements"
  add_foreign_key "settlement_rules", "merchant_profiles"
  add_foreign_key "settlements", "merchant_profiles"
  add_foreign_key "ticket_attachments", "ticket_messages"
  add_foreign_key "ticket_messages", "tickets"
end
