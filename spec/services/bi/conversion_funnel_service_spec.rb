# frozen_string_literal: true

require "rails_helper"

RSpec.describe Bi::ConversionFunnelService, type: :service do
  describe ".call" do
    context "with orders in various stages" do
      before do
        create(:order, status: "paid")
        create(:order, status: "paid")
        create(:order, status: "accepted")
        create(:order, status: "producing")
        create(:order, status: "delivered")
        create(:order, :completed)
        create(:order, :canceled)
        create(:order, :refunded)
      end

      subject(:result) { described_class.call }

      it "counts all orders at the created stage" do
        created_stage = result.stages.find { |s| s.name == "created" }
        expect(created_stage.count).to eq(8) # all orders passed through created
        expect(created_stage.rate).to eq(100.0)
      end

      it "counts orders that reached paid stage" do
        paid_stage = result.stages.find { |s| s.name == "paid" }
        # paid(2) + accepted(1) + producing(1) + delivered(1) + completed(1) = 6
        # canceled and refunded are terminal and not counted in later stages
        expect(paid_stage.count).to eq(6)
      end

      it "counts completed orders" do
        completed_stage = result.stages.find { |s| s.name == "completed" }
        expect(completed_stage.count).to eq(1) # only the 1 completed order
      end

      it "counts canceled orders" do
        expect(result.canceled_count).to eq(1)
        expect(result.canceled_rate).to eq(12.5) # 1/8 * 100
      end

      it "counts refunded orders" do
        expect(result.refunded_count).to eq(1)
        expect(result.refunded_rate).to eq(12.5)
      end

      it "returns stages in correct order" do
        stage_names = result.stages.map(&:name)
        expect(stage_names).to eq(%w[created paid accepted producing delivered completed])
      end
    end

    context "with date range filter" do
      before do
        create(:order, :paid, created_at: 5.days.ago)
        create(:order, :completed, created_at: 60.days.ago)
      end

      it "only counts orders within the range" do
        result = described_class.call(start_date: 7.days.ago.to_date, end_date: Date.today)
        created_stage = result.stages.find { |s| s.name == "created" }
        expect(created_stage.count).to eq(1) # only the recent order
      end
    end

    context "with no orders" do
      subject(:result) { described_class.call }

      it "returns zeroed stages" do
        expect(result.stages).to all(have_attributes(count: 0, rate: 0.0))
      end

      it "returns zero canceled and refunded" do
        expect(result.canceled_count).to eq(0)
        expect(result.canceled_rate).to eq(0.0)
        expect(result.refunded_count).to eq(0)
        expect(result.refunded_rate).to eq(0.0)
      end
    end

    context "with all orders in same status" do
      before do
        3.times { create(:order, :paid) }
      end

      it "handles uniform distribution" do
        result = described_class.call
        created_stage = result.stages.find { |s| s.name == "created" }
        paid_stage = result.stages.find { |s| s.name == "paid" }
        expect(created_stage.count).to eq(3)
        expect(paid_stage.count).to eq(3)
      end
    end
  end
end
