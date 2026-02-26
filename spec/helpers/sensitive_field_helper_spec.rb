# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SensitiveFieldHelper, type: :helper do
  describe '#mask_phone' do
    it 'masks a normal phone number' do
      expect(helper.mask_phone('13812345678')).to eq('138****5678')
    end

    it 'returns nil for blank input' do
      expect(helper.mask_phone(nil)).to be_nil
      expect(helper.mask_phone('')).to be_nil
    end

    it 'returns original if too short' do
      expect(helper.mask_phone('12345')).to eq('12345')
    end
  end

  describe '#mask_bank_account' do
    it 'masks a bank account number' do
      expect(helper.mask_bank_account('6222021234567890')).to eq('**** **** **** 7890')
    end

    it 'returns nil for blank input' do
      expect(helper.mask_bank_account(nil)).to be_nil
      expect(helper.mask_bank_account('')).to be_nil
    end

    it 'returns original if too short' do
      expect(helper.mask_bank_account('12')).to eq('12')
    end
  end

  describe '#can_view_sensitive?' do
    it 'returns false for nil' do
      expect(helper.can_view_sensitive?(nil)).to eq(false)
    end

    it 'returns true for super admin (admin enum)' do
      admin = AdminUser.new(role: 'admin')
      expect(helper.can_view_sensitive?(admin)).to eq(true)
    end

    it 'returns true for admin with sensitive:view_plaintext permission' do
      admin = AdminUser.create!(email: "sens_test_#{SecureRandom.hex(4)}@example.com", password: 'password', password_confirmation: 'password', role: 'operator')
      allow(admin).to receive(:admin_can?).with("sensitive:view_plaintext").and_return(true)

      expect(helper.can_view_sensitive?(admin)).to eq(true)
    end

    it 'returns false for operator without sensitive permission' do
      admin = AdminUser.create!(email: "ops_test_#{SecureRandom.hex(4)}@example.com", password: 'password', password_confirmation: 'password', role: 'operator')
      expect(helper.can_view_sensitive?(admin)).to eq(false)
    end
  end

  describe '#sensitive_field' do
    it 'returns masked value for unauthorized admin' do
      admin = AdminUser.new(role: 'operator')
      result = helper.sensitive_field('13812345678', mask_method: :mask_phone, admin_user: admin)
      expect(result).to eq('138****5678')
    end

    it 'returns original value for super admin' do
      admin = AdminUser.new(role: 'admin')
      result = helper.sensitive_field('13812345678', mask_method: :mask_phone, admin_user: admin)
      expect(result).to eq('13812345678')
    end

    it 'returns nil for blank value' do
      admin = AdminUser.new(role: 'admin')
      expect(helper.sensitive_field(nil, mask_method: :mask_phone, admin_user: admin)).to be_nil
      expect(helper.sensitive_field('', mask_method: :mask_phone, admin_user: admin)).to be_nil
    end
  end
end
