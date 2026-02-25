# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ticket, type: :model do
  def build_ticket(attrs = {})
    Ticket.new({
      subject:    "Test ticket",
      creator_id: SecureRandom.uuid,
      category:   "general",
      priority:   "normal"
    }.merge(attrs))
  end

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  describe "validations" do
    it "is valid with required attributes" do
      ticket = build_ticket
      expect(ticket).to be_valid
    end

    it "requires subject" do
      ticket = build_ticket(subject: nil)
      expect(ticket).not_to be_valid
      expect(ticket.errors[:subject]).to be_present
    end

    it "requires creator_id" do
      ticket = build_ticket(creator_id: nil)
      expect(ticket).not_to be_valid
    end

    it "validates category inclusion" do
      ticket = build_ticket(category: "invalid")
      expect(ticket).not_to be_valid
    end

    it "validates priority inclusion" do
      ticket = build_ticket(priority: "invalid")
      expect(ticket).not_to be_valid
    end

    it "auto-generates ticket_no" do
      ticket = build_ticket
      ticket.save!
      expect(ticket.ticket_no).to start_with("TK-")
    end

    it "enforces ticket_no uniqueness" do
      t1 = build_ticket
      t1.save!
      t2 = build_ticket(ticket_no: t1.ticket_no)
      expect(t2).not_to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # AASM State Machine
  # ---------------------------------------------------------------------------
  describe "AASM state transitions" do
    let(:ticket) { build_ticket.tap(&:save!) }

    it "starts in open state" do
      expect(ticket.status).to eq("open")
    end

    context "assign" do
      it "transitions open → assigned" do
        ticket.assign!
        expect(ticket.status).to eq("assigned")
      end

      it "allows re-assign (assigned → assigned)" do
        ticket.assign!
        expect { ticket.assign! }.not_to raise_error
        expect(ticket.status).to eq("assigned")
      end
    end

    context "start_work" do
      it "transitions assigned → in_progress" do
        ticket.assign!
        ticket.start_work!
        expect(ticket.status).to eq("in_progress")
      end

      it "rejects from open (not yet assigned)" do
        expect { ticket.start_work! }.to raise_error(AASM::InvalidTransition)
      end
    end

    context "resolve" do
      it "can resolve from open" do
        ticket.resolve!
        expect(ticket.status).to eq("resolved")
      end

      it "can resolve from assigned" do
        ticket.assign!
        ticket.resolve!
        expect(ticket.status).to eq("resolved")
      end

      it "can resolve from in_progress" do
        ticket.assign!
        ticket.start_work!
        ticket.resolve!
        expect(ticket.status).to eq("resolved")
      end
    end

    context "close" do
      it "can close from any active state" do
        ticket.close!
        expect(ticket.status).to eq("closed")
      end

      it "can close from resolved" do
        ticket.resolve!
        ticket.close!
        expect(ticket.status).to eq("closed")
      end
    end

    context "reopen" do
      it "can reopen from resolved" do
        ticket.resolve!
        ticket.reopen!
        expect(ticket.status).to eq("open")
      end

      it "can reopen from closed" do
        ticket.close!
        ticket.reopen!
        expect(ticket.status).to eq("open")
      end

      it "cannot reopen from open" do
        expect { ticket.reopen! }.to raise_error(AASM::InvalidTransition)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  describe "associations" do
    let(:ticket) { build_ticket.tap(&:save!) }

    it "has many messages" do
      msg = ticket.messages.create!(
        sender_id: SecureRandom.uuid,
        sender_type: "User",
        content: "Hello"
      )
      expect(ticket.messages).to include(msg)
    end

    it "has attachments through messages" do
      msg = ticket.messages.create!(
        sender_id: SecureRandom.uuid,
        content: "With attachment"
      )
      att = msg.attachments.create!(file_name: "test.pdf", url: "https://example.com/test.pdf")
      expect(ticket.attachments).to include(att)
    end
  end

  # ---------------------------------------------------------------------------
  # Messages
  # ---------------------------------------------------------------------------
  describe "TicketMessage" do
    let(:ticket) { build_ticket.tap(&:save!) }

    it "distinguishes public vs internal messages" do
      ticket.messages.create!(sender_id: SecureRandom.uuid, content: "Public", internal: false)
      ticket.messages.create!(sender_id: SecureRandom.uuid, content: "Internal", internal: true)

      expect(ticket.messages.public_messages.count).to eq(1)
      expect(ticket.messages.internal_notes.count).to eq(1)
    end
  end

  # ---------------------------------------------------------------------------
  # Attachments
  # ---------------------------------------------------------------------------
  describe "TicketAttachment" do
    let(:ticket) { build_ticket.tap(&:save!) }
    let(:msg) { ticket.messages.create!(sender_id: SecureRandom.uuid, content: "Att") }

    it "stores file metadata" do
      att = msg.attachments.create!(
        file_name: "invoice.pdf",
        file_type: "application/pdf",
        file_size: 2_048_000,
        oss_key: "uploads/invoice.pdf",
        url: "https://oss.example.com/invoice.pdf"
      )
      expect(att.file_size_display).to eq("2.0 MB")
      expect(att.download_link).to eq("https://oss.example.com/invoice.pdf")
    end

    it "falls back to oss_key when url is blank" do
      att = msg.attachments.create!(file_name: "doc.pdf", oss_key: "uploads/doc.pdf")
      expect(att.download_link).to eq("uploads/doc.pdf")
    end
  end
end
