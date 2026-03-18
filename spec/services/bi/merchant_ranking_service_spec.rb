# frozen_string_literal: true

require "rails_helper"

RSpec.describe Bi::MerchantRankingService, type: :service do
  describe ".call" do
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }
    let!(:merchant1) { create(:merchant_profile, user: user1, shop_name: "Top Shop") }
    let!(:merchant2) { create(:merchant_profile, user: user2, shop_name: "Second Shop") }

    let(:uuid1) { format("00000000-0000-0000-0000-%012d", user1.id) }
    let(:uuid2) { format("00000000-0000-0000-0000-%012d", user2.id) }

    before do
      # Merchant 1: 2 paid orders, GMV = 15_000
      create(:order, :paid, merchant_id: uuid1, total_amount: 10_000, created_at: 5.days.ago)
      create(:order, :paid, merchant_id: uuid1, total_amount: 5_000, created_at: 3.days.ago)

      # Merchant 2: 1 paid order, GMV = 8_000
      create(:order, :paid, merchant_id: uuid2, total_amount: 8_000, created_at: 4.days.ago)
    end

    context "ranking by GMV" do
      subject(:result) { described_class.call(metric: :gmv, period: :month, limit: 10) }

      it "returns merchants sorted by GMV descending" do
        expect(result.first.shop_name).to eq("Top Shop")
        expect(result.first.gmv).to eq(15_000)
        expect(result.last.shop_name).to eq("Second Shop")
      end

      it "assigns correct ranks" do
        expect(result.first.rank).to eq(1)
        expect(result.last.rank).to eq(2)
      end

      it "includes order count" do
        top = result.first
        expect(top.order_count).to eq(2)
      end
    end

    context "ranking by order count" do
      subject(:result) { described_class.call(metric: :order_count, period: :month) }

      it "returns merchants sorted by order count" do
        expect(result.first.order_count).to be >= result.last.order_count
      end
    end

    context "ranking by refund rate" do
      before do
        order = Order.where(merchant_id: uuid1).first
        payment = create(:payment, :paid, order: order, amount: order.total_amount)
        create(:refund, :succeeded, order: order, payment: payment,
               amount: 3_000, succeeded_at: 2.days.ago)
      end

      subject(:result) { described_class.call(metric: :refund_rate, period: :month) }

      it "returns merchants sorted by refund rate" do
        merchant1_result = result.find { |m| m.shop_name == "Top Shop" }
        expect(merchant1_result.refund_rate).to be > 0
      end
    end

    context "with limit parameter" do
      it "limits the number of results" do
        result = described_class.call(metric: :gmv, limit: 1)
        expect(result.length).to eq(1)
      end
    end

    context "with no merchants" do
      before do
        MerchantProfile.destroy_all
      end

      it "returns an empty array" do
        result = described_class.call
        expect(result).to eq([])
      end
    end

    context "with period filtering" do
      before do
        # Old order outside the week period
        create(:order, :paid, merchant_id: uuid1, total_amount: 50_000, created_at: 20.days.ago)
      end

      it "only includes data within the selected period" do
        result = described_class.call(metric: :gmv, period: :week)
        top = result.find { |m| m.shop_name == "Top Shop" }
        # Should not include the 50_000 order from 20 days ago
        expect(top.gmv).to eq(15_000)
      end
    end
  end
end
