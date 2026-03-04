# frozen_string_literal: true

require 'rails_helper'

# Helper module to create admin users with specific permissions
# NOTE: AdminUserRole.user_id has FK to users table, and AdminUser#admin_can?
# queries admin_user_roles WHERE user_id = admin_user.id.
# So we need a User record whose id matches the AdminUser id, OR we stub admin_can?.
# We take the stub approach for cleaner tests.
module PolicySpecHelpers
  def create_super_admin
    admin = AdminUser.create!(
      email: "super_#{SecureRandom.hex(4)}@example.com",
      password: 'Str0ng!Pass#12',
      password_confirmation: 'Str0ng!Pass#12',
      role: 'admin'  # admin enum = super admin, admin_can? returns true for everything
    )
    admin
  end

  def create_admin_with_permissions(*permission_codes)
    admin = AdminUser.create!(
      email: "perm_#{SecureRandom.hex(4)}@example.com",
      password: 'Str0ng!Pass#12',
      password_confirmation: 'Str0ng!Pass#12',
      role: 'operator'
    )
    # Stub admin_can? to check against the given permission codes
    allowed = permission_codes.map(&:to_s)
    allow(admin).to receive(:admin_can?) { |code| allowed.include?(code.to_s) }
    admin
  end

  def create_admin_without_permissions
    admin = AdminUser.create!(
      email: "noperm_#{SecureRandom.hex(4)}@example.com",
      password: 'Str0ng!Pass#12',
      password_confirmation: 'Str0ng!Pass#12',
      role: 'operator'
    )
    allow(admin).to receive(:admin_can?).and_return(false)
    admin
  end
end

RSpec.configure do |config|
  config.include PolicySpecHelpers, type: :policy
end

# =============================
# UserPolicy
# =============================
RSpec.describe UserPolicy, type: :policy do
  let(:record) { User.new }

  describe 'super_admin' do
    let(:admin) { create_super_admin }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be true }
    it { expect(subject.show?).to be true }
    it { expect(subject.create?).to be true }
    it { expect(subject.update?).to be true }
    it { expect(subject.destroy?).to be true }
    it { expect(subject.activate?).to be true }
    it { expect(subject.deactivate?).to be true }
  end

  describe 'ops admin (user:read only)' do
    let(:admin) { create_admin_with_permissions('user:read') }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be true }
    it { expect(subject.show?).to be true }
    it { expect(subject.create?).to be false }
    it { expect(subject.update?).to be false }
    it { expect(subject.activate?).to be false }
    it { expect(subject.deactivate?).to be false }
  end

  describe 'admin without any permission' do
    let(:admin) { create_admin_without_permissions }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be false }
    it { expect(subject.show?).to be false }
  end
end

# =============================
# OrderPolicy
# =============================
RSpec.describe OrderPolicy, type: :policy do
  let(:record) { Order.new }

  describe 'super_admin' do
    let(:admin) { create_super_admin }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be true }
    it { expect(subject.show?).to be true }
  end

  describe 'ops admin (order:read)' do
    let(:admin) { create_admin_with_permissions('order:read') }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be true }
    it { expect(subject.show?).to be true }
  end

  describe 'admin without order:read' do
    let(:admin) { create_admin_without_permissions }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be false }
    it { expect(subject.show?).to be false }
  end
end

# =============================
# RefundPolicy
# =============================
RSpec.describe RefundPolicy, type: :policy do
  let(:record) { Refund.new }

  describe 'super_admin' do
    let(:admin) { create_super_admin }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be true }
    it { expect(subject.approve?).to be true }
    it { expect(subject.reject?).to be true }
  end

  describe 'risk admin (refund:read + refund:approve)' do
    let(:admin) { create_admin_with_permissions('refund:read', 'refund:approve') }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be true }
    it { expect(subject.approve?).to be true }
    it { expect(subject.reject?).to be true }
  end

  describe 'ops admin (no refund permissions)' do
    let(:admin) { create_admin_with_permissions('order:read') }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be false }
    it { expect(subject.approve?).to be false }
    it { expect(subject.reject?).to be false }
  end
end

# =============================
# RiskEventPolicy
# =============================
RSpec.describe RiskEventPolicy, type: :policy do
  let(:record) { RiskEvent.new }

  describe 'risk admin (risk:read + risk:manage)' do
    let(:admin) { create_admin_with_permissions('risk:read', 'risk:manage') }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be true }
    it { expect(subject.show?).to be true }
    it { expect(subject.ignore?).to be true }
    it { expect(subject.process_event?).to be true }
  end

  describe 'ops admin (no risk permissions)' do
    let(:admin) { create_admin_with_permissions('order:read') }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be false }
    it { expect(subject.ignore?).to be false }
    it { expect(subject.process_event?).to be false }
  end
end

# =============================
# TicketPolicy
# =============================
RSpec.describe TicketPolicy, type: :policy do
  let(:record) { Ticket.new }

  describe 'ops admin (ticket:read + ticket:manage)' do
    let(:admin) { create_admin_with_permissions('ticket:read', 'ticket:manage') }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be true }
    it { expect(subject.create?).to be true }
    it { expect(subject.assign?).to be true }
    it { expect(subject.reply?).to be true }
  end

  describe 'admin with ticket:read only' do
    let(:admin) { create_admin_with_permissions('ticket:read') }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be true }
    it { expect(subject.create?).to be false }
    it { expect(subject.assign?).to be false }
  end

  describe 'admin without ticket permissions' do
    let(:admin) { create_admin_without_permissions }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be false }
  end
end

# =============================
# FeedbackPolicy
# =============================
RSpec.describe FeedbackPolicy, type: :policy do
  let(:record) { Feedback.new }

  describe 'ops admin (feedback:read + feedback:manage)' do
    let(:admin) { create_admin_with_permissions('feedback:read', 'feedback:manage') }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be true }
    it { expect(subject.update?).to be true }
    it { expect(subject.create?).to be false }
    it { expect(subject.destroy?).to be false }
  end

  describe 'admin without feedback permissions' do
    let(:admin) { create_admin_without_permissions }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be false }
    it { expect(subject.update?).to be false }
  end
end

# =============================
# ElementPolicy
# =============================
RSpec.describe ElementPolicy, type: :policy do
  let(:record) { Element.new }

  describe 'ops admin (element:read + element:manage)' do
    let(:admin) { create_admin_with_permissions('element:read', 'element:manage') }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be true }
    it { expect(subject.create?).to be true }
    it { expect(subject.shelf?).to be true }
  end

  describe 'admin with element:read only' do
    let(:admin) { create_admin_with_permissions('element:read') }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be true }
    it { expect(subject.create?).to be false }
  end
end

# =============================
# PaymentPolicy
# =============================
RSpec.describe PaymentPolicy, type: :policy do
  let(:record) { Payment.new }

  describe 'admin with payment:read' do
    let(:admin) { create_admin_with_permissions('payment:read') }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be true }
    it { expect(subject.show?).to be true }
  end

  describe 'admin without payment:read' do
    let(:admin) { create_admin_without_permissions }
    subject { described_class.new(admin, record) }

    it { expect(subject.index?).to be false }
  end
end
