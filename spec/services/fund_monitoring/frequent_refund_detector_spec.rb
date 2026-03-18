require "rails_helper"

RSpec.describe FundMonitoring::FrequentRefundDetector do
  let!(:rule) do
    create(:risk_rule,
           code:     "frequent_refund",
           category: "refund",
           severity: "high",
           enabled:  true,
           params:   { "max_count" => 3, "window_days" => 7 })
  end

  let(:order)   { create(:order) }
  let(:payment) { create(:payment, order: order) }

  def make_refund(created_offset: 0)
    create(:refund,
           payment: payment,
           order:   order,
           status:  "succeeded",
           created_at: created_offset.days.ago)
  end

  describe ".call" do
    context "when refund count >= threshold within window" do
      before { 2.times { make_refund } }  # 2 previous + the current = 3 total

      let!(:current_refund) { make_refund }

      it "creates a RiskEvent" do
        expect { described_class.call(current_refund) }.to change(RiskEvent, :count).by(1)
      end

      it "sets correct event attributes" do
        event = described_class.call(current_refund)
        expect(event.risk_rule).to eq(rule)
        expect(event.trigger_source).to eq("frequent_refund")
        expect(event.context["payment_id"]).to eq(payment.id)
      end

      context "when an event already exists for same payment in the window" do
        before { described_class.call(make_refund) }

        it "does not create a duplicate RiskEvent" do
          expect { described_class.call(current_refund) }.not_to change(RiskEvent, :count)
        end
      end
    end

    context "when refund count < threshold" do
      let!(:current_refund) { make_refund }

      it "does not create a RiskEvent" do
        expect { described_class.call(current_refund) }.not_to change(RiskEvent, :count)
      end

      it "returns nil" do
        expect(described_class.call(current_refund)).to be_nil
      end
    end

    context "when the frequent_refund rule is disabled" do
      before { rule.update!(enabled: false) }

      let!(:current_refund) { 3.times.map { make_refund }.last }

      it "does not create a RiskEvent" do
        expect { described_class.call(current_refund) }.not_to change(RiskEvent, :count)
      end

      it "returns nil gracefully" do
        expect(described_class.call(current_refund)).to be_nil
      end
    end

    context "when the frequent_refund rule does not exist" do
      before { rule.destroy }

      let!(:current_refund) { make_refund }

      it "returns nil without error" do
        expect { described_class.call(current_refund) }.not_to raise_error
        expect(described_class.call(current_refund)).to be_nil
      end
    end
  end
end
