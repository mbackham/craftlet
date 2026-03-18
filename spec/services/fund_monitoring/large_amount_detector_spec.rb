require "rails_helper"

RSpec.describe FundMonitoring::LargeAmountDetector do
  let(:order)   { create(:order) }
  let(:payment) { create(:payment, order: order, amount: amount, status: "paid") }

  describe ".call" do
    context "when amount >= threshold (50,000)" do
      let(:amount) { 55_000 }

      it "creates a FundAlert" do
        expect { described_class.call(payment) }.to change(FundAlert, :count).by(1)
      end

      it "creates alert with correct attributes" do
        alert = described_class.call(payment)
        expect(alert.subject).to eq(payment)
        expect(alert.alert_type).to eq("payment")
        expect(alert.amount).to eq(55_000)
        expect(alert.status).to eq("pending")
      end

      context "when a pending alert already exists for the same subject" do
        before { described_class.call(payment) }

        it "does not create a duplicate alert" do
          expect { described_class.call(payment) }.not_to change(FundAlert, :count)
        end
      end
    end

    context "when amount < threshold" do
      let(:amount) { 1_000 }

      it "does not create a FundAlert" do
        expect { described_class.call(payment) }.not_to change(FundAlert, :count)
      end

      it "returns nil" do
        expect(described_class.call(payment)).to be_nil
      end
    end

    context "when called with a Refund record" do
      let(:amount)  { 60_000 }
      let(:refund)  { create(:refund, payment: payment, order: order, amount: 60_000) }

      it "creates a refund-type alert" do
        alert = described_class.call(refund)
        expect(alert.alert_type).to eq("refund")
        expect(alert.subject).to eq(refund)
      end
    end
  end
end
