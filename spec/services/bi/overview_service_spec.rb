# frozen_string_literal: true

require "rails_helper"

RSpec.describe Bi::OverviewService, type: :service do
  describe ".call" do
    context "with data in the current period" do
      let!(:user1) { create(:user) }
      let!(:user2) { create(:user) }
      let!(:merchant) { create(:merchant_profile, user: user1) }

      let!(:paid_order) do
        create(:order, :paid, total_amount: 10_000, created_at: 5.days.ago)
      end
      let!(:completed_order) do
        create(:order, :completed, total_amount: 20_000, created_at: 3.days.ago)
      end
      let!(:canceled_order) do
        create(:order, :canceled, total_amount: 5_000, created_at: 2.days.ago)
      end

      let!(:payment_paid) do
        create(:payment, :paid, order: paid_order, amount: 10_000, created_at: 5.days.ago)
      end
      let!(:payment_failed) do
        create(:payment, order: canceled_order, amount: 5_000, status: "failed", created_at: 2.days.ago)
      end

      let!(:refund) do
        create(:refund, :succeeded, order: paid_order, payment: payment_paid,
               amount: 2_000, succeeded_at: 4.days.ago)
      end

      let!(:settlement) do
        create(:settlement, :confirmed, merchant_profile: merchant,
               net_amount: 8_000, confirmed_at: 1.day.ago)
      end

      subject(:result) { described_class.call(period: :month) }

      it "calculates GMV from paid statuses" do
        # paid + completed = 10_000 + 20_000 = 30_000
        expect(result.gmv).to eq(30_000)
      end

      it "counts total orders" do
        expect(result.order_count).to eq(3) # all 3 orders
      end

      it "counts paid orders only" do
        expect(result.paid_order_count).to eq(2) # paid + completed
      end

      it "counts users" do
        expect(result.user_count).to eq(2)
      end

      it "counts approved merchants" do
        expect(result.merchant_count).to eq(1)
      end

      it "calculates payment success rate" do
        # 1 paid out of 2 total = 50%
        expect(result.payment_success_rate).to eq(50.0)
      end

      it "calculates refund rate" do
        # 2_000 / 30_000 * 100 = 6.67%
        expect(result.refund_rate).to eq(6.67)
      end

      it "calculates average order value" do
        # 30_000 / 2 paid orders = 15_000
        expect(result.avg_order_value).to eq(15_000.0)
      end

      it "calculates total refund" do
        expect(result.total_refund).to eq(2_000)
      end

      it "calculates net income" do
        expect(result.net_income).to eq(28_000) # 30_000 - 2_000
      end

      it "calculates settled amount" do
        expect(result.settled_amount).to eq(8_000)
      end
    end

    context "with no data" do
      subject(:result) { described_class.call(period: :month) }

      it "returns zeros without error" do
        expect(result.gmv).to eq(0)
        expect(result.order_count).to eq(0)
        expect(result.paid_order_count).to eq(0)
        expect(result.payment_success_rate).to eq(0.0)
        expect(result.refund_rate).to eq(0.0)
        expect(result.avg_order_value).to eq(0.0)
        expect(result.net_income).to eq(0)
      end
    end

    context "with different periods" do
      let!(:recent_order) do
        create(:order, :paid, total_amount: 5_000, created_at: 3.days.ago)
      end
      let!(:old_order) do
        create(:order, :paid, total_amount: 10_000, created_at: 60.days.ago)
      end

      it "filters by week period" do
        result = described_class.call(period: :week)
        expect(result.gmv).to eq(5_000)
      end

      it "includes older data in month period" do
        result = described_class.call(period: :quarter)
        expect(result.gmv).to eq(15_000)
      end
    end

    context "growth calculation" do
      it "calculates positive growth" do
        # Previous period: 40+ days ago
        create(:order, :paid, total_amount: 5_000, created_at: 45.days.ago)
        # Current period: within 30 days
        create(:order, :paid, total_amount: 10_000, created_at: 5.days.ago)

        result = described_class.call(period: :month)
        expect(result.gmv_growth).to eq(100.0) # (10_000 - 5_000) / 5_000 * 100
      end

      it "returns 0 growth when no previous data" do
        create(:order, :paid, total_amount: 10_000, created_at: 5.days.ago)
        result = described_class.call(period: :month)
        expect(result.gmv_growth).to eq(0.0)
      end
    end
  end
end
