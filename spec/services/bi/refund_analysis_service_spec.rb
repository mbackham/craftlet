# frozen_string_literal: true

require "rails_helper"

RSpec.describe Bi::RefundAnalysisService, type: :service do
  describe ".call" do
    let(:start_date) { 30.days.ago.to_date }
    let(:end_date)   { Date.today }

    context "with refund data" do
      let!(:order1) { create(:order, :paid, total_amount: 10_000, created_at: 5.days.ago) }
      let!(:order2) { create(:order, :paid, total_amount: 20_000, created_at: 3.days.ago) }
      let!(:payment1) { create(:payment, :paid, order: order1, amount: 10_000) }
      let!(:payment2) { create(:payment, :paid, order: order2, amount: 20_000) }

      let!(:refund1) do
        create(:refund, :succeeded, order: order1, payment: payment1,
               amount: 2_000, reason: "quality_issue", succeeded_at: 4.days.ago)
      end
      let!(:refund2) do
        create(:refund, :succeeded, order: order1, payment: payment1,
               amount: 1_000, reason: "quality_issue", succeeded_at: 3.days.ago)
      end
      let!(:refund3) do
        create(:refund, :succeeded, order: order2, payment: payment2,
               amount: 5_000, reason: "wrong_item", succeeded_at: 2.days.ago)
      end

      subject(:result) { described_class.call(start_date: start_date, end_date: end_date) }

      it "calculates total refund count" do
        expect(result.total_refund_count).to eq(3)
      end

      it "calculates total refund amount" do
        expect(result.total_refund_amount).to eq(8_000) # 2_000 + 1_000 + 5_000
      end

      it "calculates refund rate against GMV" do
        # GMV = 30_000, refunds = 8_000 → 26.67%
        expect(result.refund_rate).to eq(26.67)
      end

      it "calculates average refund amount" do
        # 8_000 / 3 = 2666.67
        expect(result.avg_refund_amount).to eq(2666.67)
      end

      it "builds reason breakdown" do
        expect(result.reason_breakdown.length).to eq(2)

        quality = result.reason_breakdown.find { |r| r.reason == "quality_issue" }
        expect(quality.count).to eq(2)
        expect(quality.amount).to eq(3_000)
        expect(quality.percentage).to eq(66.67)

        wrong_item = result.reason_breakdown.find { |r| r.reason == "wrong_item" }
        expect(wrong_item.count).to eq(1)
        expect(wrong_item.amount).to eq(5_000)
      end

      it "sorts reason breakdown by count descending" do
        expect(result.reason_breakdown.first.count).to be >= result.reason_breakdown.last.count
      end
    end

    context "with no refund data" do
      subject(:result) { described_class.call(start_date: start_date, end_date: end_date) }

      it "returns zeros" do
        expect(result.total_refund_count).to eq(0)
        expect(result.total_refund_amount).to eq(0)
        expect(result.refund_rate).to eq(0.0)
        expect(result.avg_refund_amount).to eq(0.0)
      end

      it "returns empty breakdowns" do
        expect(result.reason_breakdown).to be_empty
        expect(result.top_refund_merchants).to be_empty
      end
    end

    context "with refunds outside the date range" do
      before do
        order = create(:order, :paid, total_amount: 5_000, created_at: 60.days.ago)
        payment = create(:payment, :paid, order: order, amount: 5_000)
        create(:refund, :succeeded, order: order, payment: payment,
               amount: 1_000, succeeded_at: 60.days.ago)
      end

      it "does not include out-of-range refunds" do
        result = described_class.call(start_date: start_date, end_date: end_date)
        expect(result.total_refund_count).to eq(0)
      end
    end

    context "with nil reason" do
      before do
        order = create(:order, :paid, total_amount: 5_000, created_at: 3.days.ago)
        payment = create(:payment, :paid, order: order, amount: 5_000)
        create(:refund, :succeeded, order: order, payment: payment,
               amount: 1_000, reason: nil, succeeded_at: 2.days.ago)
      end

      it "handles nil reasons gracefully" do
        result = described_class.call(start_date: start_date, end_date: end_date)
        unspecified = result.reason_breakdown.find { |r| r.reason == "unspecified" }
        expect(unspecified).to be_present
        expect(unspecified.count).to eq(1)
      end
    end

    context "merchant_limit parameter" do
      it "defaults to 5 merchants" do
        result = described_class.call(start_date: start_date, end_date: end_date)
        expect(result.top_refund_merchants.length).to be <= 5
      end
    end
  end
end
