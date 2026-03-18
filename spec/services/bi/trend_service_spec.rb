# frozen_string_literal: true

require "rails_helper"

RSpec.describe Bi::TrendService, type: :service do
  describe ".call" do
    let(:start_date) { 7.days.ago.to_date }
    let(:end_date)   { Date.today }

    context "with daily grouping" do
      before do
        create(:order, :paid, total_amount: 1_000, created_at: 3.days.ago)
        create(:order, :paid, total_amount: 2_000, created_at: 3.days.ago)
        order3 = create(:order, :paid, total_amount: 3_000, created_at: 1.day.ago)

        payment = create(:payment, :paid, order: order3, amount: 3_000)
        create(:refund, :succeeded, order: order3, payment: payment,
               amount: 500, succeeded_at: 3.days.ago)
      end

      subject(:result) { described_class.call(start_date: start_date, end_date: end_date, group_by: :day) }

      it "returns points for the date range" do
        expect(result.points.length).to eq((end_date - start_date).to_i + 1)
      end

      it "groups data by day" do
        expect(result.group_by).to eq(:day)
      end

      it "calculates summary totals" do
        expect(result.summary.total_gmv).to eq(6_000)
        expect(result.summary.total_orders).to eq(3)
        expect(result.summary.total_refunds).to eq(500)
        expect(result.summary.total_net).to eq(5_500)
      end

      it "calculates average daily GMV" do
        days = (end_date - start_date).to_i + 1
        expect(result.summary.avg_daily_gmv).to eq((6_000.0 / days).round(2))
      end

      it "has correct data for a specific day" do
        day_3_ago = result.points.find { |p| p.date == 3.days.ago.to_date }
        expect(day_3_ago).to be_present
        expect(day_3_ago.gmv).to eq(3_000)
        expect(day_3_ago.order_count).to be >= 2
      end
    end

    context "with no data in range" do
      subject(:result) { described_class.call(start_date: start_date, end_date: end_date) }

      it "returns points with zero values" do
        expect(result.points).to all(have_attributes(gmv: 0, order_count: 0, refund_amount: 0, net_income: 0))
      end

      it "returns zero summary" do
        expect(result.summary.total_gmv).to eq(0)
        expect(result.summary.total_orders).to eq(0)
      end
    end

    context "with data outside the range" do
      before do
        create(:order, :paid, total_amount: 5_000, created_at: 30.days.ago)
      end

      it "does not include out-of-range data" do
        result = described_class.call(start_date: start_date, end_date: end_date)
        expect(result.summary.total_gmv).to eq(0)
      end
    end

    context "with weekly grouping" do
      before do
        create(:order, :paid, total_amount: 1_000, created_at: 2.days.ago)
        create(:order, :paid, total_amount: 2_000, created_at: 5.days.ago)
      end

      it "groups data by week" do
        result = described_class.call(
          start_date: 14.days.ago.to_date,
          end_date: Date.today,
          group_by: :week
        )
        expect(result.group_by).to eq(:week)
        expect(result.points.length).to be >= 1
        expect(result.summary.total_gmv).to eq(3_000)
      end
    end

    context "with monthly grouping" do
      before do
        create(:order, :paid, total_amount: 5_000, created_at: 10.days.ago)
      end

      it "groups data by month" do
        result = described_class.call(
          start_date: 60.days.ago.to_date,
          end_date: Date.today,
          group_by: :month
        )
        expect(result.group_by).to eq(:month)
        expect(result.points.length).to be >= 1
        expect(result.summary.total_gmv).to eq(5_000)
      end
    end

    context "with invalid group_by" do
      it "defaults to daily grouping" do
        result = described_class.call(group_by: :invalid)
        expect(result.group_by).to eq(:day)
      end
    end
  end
end
