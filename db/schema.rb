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

ActiveRecord::Schema[7.1].define(version: 2026_03_04_055649) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  add_foreign_key "admin_role_permissions", "admin_permissions"
  add_foreign_key "admin_role_permissions", "admin_roles"
  add_foreign_key "admin_user_roles", "admin_roles"
  add_foreign_key "admin_user_roles", "users"
  add_foreign_key "bids", "orders"
  add_foreign_key "feedbacks", "admin_users", on_delete: :nullify
  add_foreign_key "feedbacks", "users", on_delete: :nullify
  add_foreign_key "merchant_profiles", "users"
  add_foreign_key "merchant_review_logs", "merchant_profiles"
  add_foreign_key "order_items", "orders"
  add_foreign_key "payment_callbacks", "payments"
  add_foreign_key "payments", "orders"
  add_foreign_key "refunds", "orders"
  add_foreign_key "refunds", "payments"
  add_foreign_key "risk_events", "risk_rules"
  add_foreign_key "roles", "users"
  add_foreign_key "ticket_attachments", "ticket_messages"
  add_foreign_key "ticket_messages", "tickets"
end
