require "rails_helper"

RSpec.describe FundAlert, type: :model do
  let(:payment) { create(:payment, amount: 60_000, status: "paid") }

  describe "validations" do
    subject { build(:fund_alert, subject: payment) }

    it { is_expected.to validate_presence_of(:alert_type) }
    it { is_expected.to validate_presence_of(:subject_type) }
    it { is_expected.to validate_presence_of(:subject_id) }
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_presence_of(:threshold) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than(0) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:subject) }
    it { is_expected.to belong_to(:handler_admin).optional }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:alert_type).with_values(payment: "payment", refund: "refund", settlement: "settlement") }
    it { is_expected.to define_enum_for(:status).with_values(pending: "pending", acknowledged: "acknowledged", ignored: "ignored") }
  end

  describe "scopes" do
    let!(:pending_alert)      { create(:fund_alert, subject: payment, status: "pending") }
    let!(:acknowledged_alert) { create(:fund_alert, subject: payment, status: "acknowledged") }

    describe ".pending" do
      it "returns only pending alerts" do
        expect(FundAlert.pending).to include(pending_alert)
        expect(FundAlert.pending).not_to include(acknowledged_alert)
      end
    end

    describe ".today" do
      it "returns alerts created today" do
        expect(FundAlert.today).to include(pending_alert)
      end

      it "excludes alerts from other days" do
        old_alert = create(:fund_alert, subject: payment, created_at: 2.days.ago)
        expect(FundAlert.today).not_to include(old_alert)
      end
    end
  end
end
