# frozen_string_literal: true

FactoryBot.define do
  # ── User ──
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    phone { "138#{rand(10_000_000..99_999_999)}" }
    nickname { "User #{SecureRandom.hex(3)}" }
    status { "active" }
    jti { SecureRandom.uuid }
  end

  # ── AdminUser ──
  factory :admin_user do
    sequence(:email) { |n| "admin#{n}@example.com" }
    password { "password123" }
    role { "admin" }
  end

  # ── MerchantProfile ──
  factory :merchant_profile do
    association :user
    shop_name { "Shop #{SecureRandom.hex(3)}" }
    status { "approved" }
    address_province { "广东省" }
    address_city { "深圳市" }
  end

  # ── Order ──
  factory :order do
    sequence(:order_no) { |n| "ORD#{Time.current.strftime('%Y%m%d')}#{n.to_s.rjust(6, '0')}" }
    customer_id { SecureRandom.uuid }
    merchant_id { SecureRandom.uuid }
    status { "pending" }
    total_amount { rand(100..10_000).to_d }
    currency { "CNY" }

    trait :paid do
      status { "paid" }
      paid_at { Time.current }
    end

    trait :completed do
      status { "completed" }
      paid_at { 3.days.ago }
      completed_at { Time.current }
    end

    trait :canceled do
      status { "canceled" }
      canceled_at { Time.current }
    end

    trait :refunded do
      status { "refunded" }
      paid_at { 3.days.ago }
    end
  end

  # ── Payment ──
  factory :payment do
    association :order
    channel { "wechat" }
    status { "init" }
    amount { order&.total_amount || rand(100..10_000).to_d }
    currency { "CNY" }
    sequence(:idempotency_key) { |n| "PAY-#{SecureRandom.hex(6)}-#{n}" }

    trait :paid do
      status { "paid" }
      paid_at { Time.current }
    end
  end

  # ── Refund ──
  factory :refund do
    association :order
    association :payment
    amount { rand(50..5_000).to_d }
    reason { %w[quality_issue wrong_item not_as_described].sample }
    status { "init" }
    sequence(:idempotency_key) { |n| "REF-#{SecureRandom.hex(6)}-#{n}" }

    trait :succeeded do
      status { "succeeded" }
      succeeded_at { Time.current }
    end
  end

  # ── Settlement ──
  factory :settlement do
    association :merchant_profile
    sequence(:settlement_no) { |n| "ST#{Time.current.strftime('%Y%m%d')}#{n.to_s.rjust(4, '0')}" }
    period_start { 7.days.ago.to_date }
    period_end { Date.today }
    total_order_amount { rand(5_000..100_000).to_d }
    total_refund_amount { rand(0..5_000).to_d }
    net_amount { total_order_amount - total_refund_amount }
    status { "pending_review" }

    trait :confirmed do
      status { "confirmed" }
      confirmed_at { Time.current }
    end
  end

  # ── FundAlert ──
  factory :fund_alert do
    association :subject, factory: [:payment, :paid]
    alert_type { "payment" }
    amount { rand(50_000..200_000).to_d }
    threshold { 50_000 }
    status { "pending" }
  end

  # ── RiskRule ──
  factory :risk_rule do
    sequence(:code) { |n| "RULE_#{n}" }
    sequence(:name) { |n| "Risk Rule #{n}" }
    description { "Auto-generated risk rule" }
    category { "general" }
    severity { "medium" }
    enabled { true }
  end

  # ── RiskEvent ──
  factory :risk_event do
    association :risk_rule
    status { "pending" }
    subject_id { SecureRandom.uuid }
    subject_type { "User" }
    trigger_source { "system" }
  end
end
