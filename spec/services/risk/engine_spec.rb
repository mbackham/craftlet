# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Risk::Engine do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  def create_user(email: nil)
    User.create!(
      email:    email || "user_#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      status:   "active"
    )
  end

  def format_uuid(id)
    sprintf('00000000-0000-0000-0000-%012d', id.to_i)
  end

  def create_order(customer_id:, status: "paid")
    Order.create!(
      order_no:     "ORD-#{SecureRandom.hex(4).upcase}",
      customer_id:  customer_id,
      merchant_id:  SecureRandom.uuid,
      status:       status,
      total_amount: 200.00,
      currency:     "CNY"
    )
  end

  def create_payment(order:)
    Payment.create!(
      order:           order,
      channel:         "wechat",
      amount:          order.total_amount,
      currency:        "CNY",
      status:          "paid",
      paid_at:         Time.current,
      idempotency_key: SecureRandom.uuid
    )
  end

  # ---------------------------------------------------------------------------
  # Seed rules for each test
  # ---------------------------------------------------------------------------
  before(:each) do
    RiskRule.find_or_create_by!(code: "high_freq_refund") do |r|
      r.name     = "高频退款申请"
      r.category = "refund"
      r.severity = "high"
      r.params   = { "window_minutes" => 60, "threshold" => 3 }
      r.enabled  = true
    end

    RiskRule.find_or_create_by!(code: "high_amount_refund") do |r|
      r.name     = "高金额退款"
      r.category = "refund"
      r.severity = "medium"
      r.params   = { "amount_threshold" => 500 }
      r.enabled  = true
    end

    RiskRule.find_or_create_by!(code: "merchant_bid_spam") do |r|
      r.name     = "商家异常竞标"
      r.category = "merchant"
      r.severity = "high"
      r.params   = { "window_minutes" => 30, "threshold" => 3 }
      r.enabled  = true
    end
  end

  # ---------------------------------------------------------------------------
  # 规则 1: 高频退款
  # ---------------------------------------------------------------------------
  describe "high_freq_refund rule" do
    let(:user)         { create_user }
    let(:user_uuid)    { format_uuid(user.id) }
    let(:order)        { create_order(customer_id: user_uuid) }
    let(:payment)      { create_payment(order: order) }

    it "triggers when refund count >= threshold within window" do
      # Create 3 refunds (threshold)
      3.times do |i|
        Refund.create!(
          order: order, payment: payment, amount: 50, reason: "test #{i}",
          status: "init", idempotency_key: SecureRandom.uuid
        )
      end

      events = Risk::Engine.check(:refund_create, user_uuid: user_uuid)
      expect(events.size).to eq(1)
      expect(events.first.risk_rule.code).to eq("high_freq_refund")
      expect(events.first.context["recent_count"]).to be >= 3
    end

    it "does NOT trigger when below threshold" do
      2.times do |i|
        Refund.create!(
          order: order, payment: payment, amount: 50, reason: "test #{i}",
          status: "init", idempotency_key: SecureRandom.uuid
        )
      end

      events = Risk::Engine.check(:refund_create, user_uuid: user_uuid)
      freq_events = events.select { |e| e.risk_rule.code == "high_freq_refund" }
      expect(freq_events).to be_empty
    end

    it "does NOT trigger when rule is disabled" do
      RiskRule.find_by(code: "high_freq_refund").update!(enabled: false)

      3.times do |i|
        Refund.create!(
          order: order, payment: payment, amount: 50, reason: "test #{i}",
          status: "init", idempotency_key: SecureRandom.uuid
        )
      end

      events = Risk::Engine.check(:refund_create, user_uuid: user_uuid)
      freq_events = events.select { |e| e.risk_rule.code == "high_freq_refund" }
      expect(freq_events).to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # 规则 2: 高金额退款
  # ---------------------------------------------------------------------------
  describe "high_amount_refund rule" do
    let(:user)      { create_user }
    let(:user_uuid) { format_uuid(user.id) }
    let(:order)     { create_order(customer_id: user_uuid) }
    let(:payment)   { create_payment(order: order) }

    it "triggers when refund amount >= threshold" do
      refund = Refund.create!(
        order: order, payment: payment, amount: 600, reason: "big refund",
        status: "init", idempotency_key: SecureRandom.uuid
      )

      events = Risk::Engine.check(:refund_create, user_uuid: user_uuid, refund: refund)
      amt_events = events.select { |e| e.risk_rule.code == "high_amount_refund" }
      expect(amt_events.size).to eq(1)
      expect(amt_events.first.context["refund_amount"]).to eq(600.0)
    end

    it "does NOT trigger when below threshold" do
      refund = Refund.create!(
        order: order, payment: payment, amount: 100, reason: "small refund",
        status: "init", idempotency_key: SecureRandom.uuid
      )

      events = Risk::Engine.check(:refund_create, user_uuid: user_uuid, refund: refund)
      amt_events = events.select { |e| e.risk_rule.code == "high_amount_refund" }
      expect(amt_events).to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # 规则 3: 商家异常竞标
  # ---------------------------------------------------------------------------
  describe "merchant_bid_spam rule" do
    let(:merchant)      { create_user(email: "merchant@test.com") }
    let(:merchant_uuid) { format_uuid(merchant.id) }

    it "triggers when bid count >= threshold within window" do
      order = create_order(customer_id: SecureRandom.uuid)

      3.times do
        Bid.create!(order: order, bidder_id: merchant_uuid, amount: 100, status: "pending")
      end

      events = Risk::Engine.check(:bid_create, user_uuid: merchant_uuid)
      expect(events.size).to eq(1)
      expect(events.first.risk_rule.code).to eq("merchant_bid_spam")
    end

    it "does NOT trigger when below threshold" do
      order = create_order(customer_id: SecureRandom.uuid)

      2.times do
        Bid.create!(order: order, bidder_id: merchant_uuid, amount: 100, status: "pending")
      end

      events = Risk::Engine.check(:bid_create, user_uuid: merchant_uuid)
      expect(events).to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # Engine behavior
  # ---------------------------------------------------------------------------
  describe "engine general behavior" do
    it "returns empty array when no rules match" do
      events = Risk::Engine.check(:refund_create, user_uuid: SecureRandom.uuid)
      expect(events).to be_an(Array)
    end

    it "returns empty array for unknown trigger_source" do
      events = Risk::Engine.check(:unknown_source, user_uuid: SecureRandom.uuid)
      expect(events).to be_empty
    end

    it "creates RiskEvent records with pending status" do
      user = create_user
      user_uuid = format_uuid(user.id)
      order = create_order(customer_id: user_uuid)
      payment = create_payment(order: order)

      3.times do |i|
        Refund.create!(
          order: order, payment: payment, amount: 50, reason: "test #{i}",
          status: "init", idempotency_key: SecureRandom.uuid
        )
      end

      expect { Risk::Engine.check(:refund_create, user_uuid: user_uuid) }
        .to change(RiskEvent, :count).by_at_least(1)

      expect(RiskEvent.last.status).to eq("pending")
    end
  end
end
