# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::AssignMerchantService do
  # ---------------------------------------------------------------------------
  # Test helpers
  # ---------------------------------------------------------------------------
  def create_order(status:, customer_id: nil, merchant_id: nil)
    Order.create!(
      order_no:     "ORD-#{SecureRandom.hex(4).upcase}",
      customer_id:  customer_id || SecureRandom.uuid,
      merchant_id:  merchant_id || SecureRandom.uuid,
      status:       status,
      total_amount: 200.00,
      currency:     "CNY"
    )
  end

  def create_merchant_user(active: true)
    user = User.create!(
      email:    "merchant_#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      status:   active ? "active" : "disabled"
    )
    user.roles.create!(role_type: "merchant", is_active: true)
    MerchantProfile.create!(
      user:      user,
      shop_name: "Test Shop #{SecureRandom.hex(3)}",
      status:    "approved"
    )
    user
  end

  def format_uuid(id)
    sprintf('00000000-0000-0000-0000-%012d', id.to_i)
  end

  let(:merchant_user) { create_merchant_user }
  let(:customer_uuid) { SecureRandom.uuid }
  let(:order)         { create_order(status: "paid", customer_id: customer_uuid) }
  let(:admin_user)    { AdminUser.first || AdminUser.create!(email: "admin@test.com", password: "Str0ng!Pass#12", password_confirmation: "Str0ng!Pass#12") }

  def run_service(overrides = {})
    Orders::AssignMerchantService.new(
      order:         overrides[:order] || order,
      merchant_user: overrides[:merchant_user] || merchant_user,
      admin_user:    overrides[:admin_user] || admin_user,
      request:       nil
    ).call
  end

  # ---------------------------------------------------------------------------
  # Success path
  # ---------------------------------------------------------------------------
  context "成功指派商家" do
    it "transitions order status from paid to accepted" do
      result = run_service
      expect(result).to be_success
      expect(order.reload.status).to eq("accepted")
    end

    it "updates order.merchant_id to the assigned merchant" do
      result = run_service
      expect(result).to be_success
      expect(order.reload.merchant_id).to eq(format_uuid(merchant_user.id))
    end

    it "creates an accepted Bid for the merchant" do
      expect { run_service }.to change(Bid, :count).by(1)
      bid = order.bids.last
      expect(bid.status).to eq("accepted")
      expect(bid.bidder_id).to eq(format_uuid(merchant_user.id))
      expect(bid.amount).to eq(order.total_amount)
    end

    it "rejects other pending Bids" do
      # Create two existing pending bids
      pending_bid = Bid.create!(order: order, bidder_id: SecureRandom.uuid, amount: 150, status: "pending")
      another_bid = Bid.create!(order: order, bidder_id: SecureRandom.uuid, amount: 180, status: "pending")

      run_service

      expect(pending_bid.reload.status).to eq("rejected")
      expect(another_bid.reload.status).to eq("rejected")
    end

    it "creates an AuditLog entry" do
      expect { run_service }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("assign_merchant")
      expect(log.metadata["merchant_email"]).to eq(merchant_user.email)
    end
  end

  # ---------------------------------------------------------------------------
  # Validation failures
  # ---------------------------------------------------------------------------
  context "订单状态不允许" do
    it "rejects when order is not in paid status" do
      order.update_column(:status, "accepted")
      result = run_service
      expect(result).not_to be_success
      expect(result.error).to include("订单状态不允许")
    end

    %w[created producing delivered completed canceled refunded].each do |bad_status|
      it "rejects when order status is #{bad_status}" do
        order.update_column(:status, bad_status)
        result = run_service
        expect(result).not_to be_success
      end
    end
  end

  context "商家用户已冻结" do
    it "rejects when merchant user status is disabled" do
      merchant_user.update_column(:status, "disabled")
      result = run_service
      expect(result).not_to be_success
      expect(result.error).to include("冻结")
    end
  end

  context "商家资质未审核通过" do
    it "rejects when MerchantProfile is not approved" do
      merchant_user.merchant_profile.update_column(:status, "pending")
      result = run_service
      expect(result).not_to be_success
      expect(result.error).to include("资质未审核通过")
    end

    it "rejects when MerchantProfile is suspended" do
      merchant_user.merchant_profile.update_column(:status, "suspended")
      result = run_service
      expect(result).not_to be_success
      expect(result.error).to include("资质未审核通过")
    end
  end

  context "自我指派" do
    it "rejects when merchant is the same as the customer" do
      merchant_uuid = format_uuid(merchant_user.id)
      self_order = create_order(status: "paid", customer_id: merchant_uuid)
      result = run_service(order: self_order)
      expect(result).not_to be_success
      expect(result.error).to include("下单用户自己")
    end
  end

  context "无 MerchantProfile" do
    it "rejects when merchant has no MerchantProfile" do
      user_no_profile = User.create!(
        email:    "noprofile@test.com",
        password: "password123",
        status:   "active"
      )
      result = run_service(merchant_user: user_no_profile)
      expect(result).not_to be_success
      expect(result.error).to include("资质未审核通过")
    end
  end
end
