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

ActiveRecord::Schema[7.1].define(version: 2026_01_10_102135) do
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

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
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
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["actor_type", "actor_id"], name: "index_audit_logs_on_actor_type_and_actor_id"
    t.index ["subject_type", "subject_id"], name: "index_audit_logs_on_subject_type_and_subject_id"
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
    t.index ["idempotency_key"], name: "index_refunds_on_idempotency_key", unique: true
    t.index ["order_id"], name: "index_refunds_on_order_id"
    t.index ["payment_id"], name: "index_refunds_on_payment_id"
    t.index ["provider_refund_no"], name: "index_refunds_on_provider_refund_no", unique: true
    t.index ["status"], name: "index_refunds_on_status"
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
    t.index ["disabled_at"], name: "index_users_on_disabled_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["phone"], name: "index_users_on_phone", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["status"], name: "index_users_on_status"
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

  add_foreign_key "merchant_profiles", "users"
  add_foreign_key "merchant_review_logs", "merchant_profiles"
  add_foreign_key "payment_callbacks", "payments"
  add_foreign_key "payments", "orders"
  add_foreign_key "refunds", "orders"
  add_foreign_key "refunds", "payments"
  add_foreign_key "roles", "users"
end
