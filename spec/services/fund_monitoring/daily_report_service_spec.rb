require "rails_helper"

RSpec.describe FundMonitoring::DailyReportService do
  let(:target_date) { Date.today }

  describe ".call" do
    context "when there is data for the day" do
      before do
        # Successful payments
        create(:payment, status: "paid", amount: 10_000,
               paid_at: target_date.beginning_of_day + 1.hour)
        create(:payment, status: "paid", amount: 20_000,
               paid_at: target_date.beginning_of_day + 2.hours)

        # Successful refunds
        create(:refund, status: "succeeded", amount: 3_000,
               succeeded_at: target_date.beginning_of_day + 3.hours)

        # Confirmed settlement
        create(:settlement, status: "confirmed", net_amount: 15_000,
               confirmed_at: target_date.beginning_of_day + 4.hours)

        # A large-amount alert
        create(:fund_alert, created_at: target_date.beginning_of_day + 1.hour)
      end

      subject(:report) { described_class.call(date: target_date) }

      it "calculates total income correctly" do
        expect(report.income).to eq(30_000)
      end

      it "counts payment records" do
        expect(report.income_count).to eq(2)
      end

      it "calculates total refunds correctly" do
        expect(report.refund_total).to eq(3_000)
      end

      it "counts refund records" do
        expect(report.refund_count).to eq(1)
      end

      it "calculates net correctly" do
        expect(report.net).to eq(27_000)  # 30_000 - 3_000
      end

      it "calculates settled amount" do
        expect(report.settled).to eq(15_000)
      end

      it "counts alerts" do
        expect(report.alert_count).to eq(1)
      end
    end

    context "when there is no data" do
      subject(:report) { described_class.call(date: target_date) }

      it "returns zeros without error" do
        expect(report.income).to eq(0)
        expect(report.refund_total).to eq(0)
        expect(report.net).to eq(0)
        expect(report.settled).to eq(0)
        expect(report.alert_count).to eq(0)
      end
    end

    context "when querying a different date" do
      before do
        create(:payment, status: "paid", amount: 5_000,
               paid_at: 3.days.ago.beginning_of_day + 1.hour)
      end

      it "only returns data for the requested date" do
        report = described_class.call(date: target_date)
        expect(report.income).to eq(0)
      end
    end
  end
end
