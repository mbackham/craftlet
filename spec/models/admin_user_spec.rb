# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminUser, type: :model do
  # ---------------------------------------------------------------------------
  # Helper — build valid admin user
  # ---------------------------------------------------------------------------
  def build_admin(overrides = {})
    AdminUser.new({
      email:                 "admin_#{SecureRandom.hex(4)}@test.com",
      password:              "Str0ng!Pass#12",
      password_confirmation: "Str0ng!Pass#12",
      role:                  "operator"
    }.merge(overrides))
  end

  # ===========================================================================
  # Password Complexity
  # ===========================================================================
  describe "password complexity" do
    it "rejects passwords shorter than 12 characters" do
      user = build_admin(password: "Ab1!aaaaa", password_confirmation: "Ab1!aaaaa")
      expect(user).not_to be_valid
      expect(user.errors[:password].join).to include("12")
    end

    it "rejects passwords without uppercase letters" do
      user = build_admin(password: "str0ng!pass#12", password_confirmation: "str0ng!pass#12")
      expect(user).not_to be_valid
      expect(user.errors[:password].join).to include("大写")
    end

    it "rejects passwords without lowercase letters" do
      user = build_admin(password: "STR0NG!PASS#12", password_confirmation: "STR0NG!PASS#12")
      expect(user).not_to be_valid
      expect(user.errors[:password].join).to include("小写")
    end

    it "rejects passwords without digits" do
      user = build_admin(password: "Strong!Pass##ab", password_confirmation: "Strong!Pass##ab")
      expect(user).not_to be_valid
      expect(user.errors[:password].join).to include("数字")
    end

    it "rejects passwords without special characters" do
      user = build_admin(password: "Str0ngPass1234", password_confirmation: "Str0ngPass1234")
      expect(user).not_to be_valid
      expect(user.errors[:password].join).to include("特殊")
    end

    it "accepts passwords meeting all complexity requirements" do
      user = build_admin(password: "Str0ng!Pass#12", password_confirmation: "Str0ng!Pass#12")
      expect(user).to be_valid
    end

    it "allows the classic Devise minimum length to be bypassed (6 < 12)" do
      user = build_admin(password: "Ab1!cd", password_confirmation: "Ab1!cd")
      expect(user).not_to be_valid
    end
  end

  # ===========================================================================
  # Devise Modules
  # ===========================================================================
  describe "Devise modules" do
    it "includes :lockable" do
      expect(AdminUser.devise_modules).to include(:lockable)
    end

    it "includes :trackable" do
      expect(AdminUser.devise_modules).to include(:trackable)
    end

    it "includes :timeoutable" do
      expect(AdminUser.devise_modules).to include(:timeoutable)
    end

    describe "lockable behavior" do
      before do
        # Devise lockable sends unlock emails → needs a host configured
        ActionMailer::Base.default_url_options = { host: 'localhost' }
      end

      let!(:admin) do
        AdminUser.create!(
          email:                 "lock_test_#{SecureRandom.hex(4)}@test.com",
          password:              "Str0ng!Pass#12",
          password_confirmation: "Str0ng!Pass#12",
          role:                  "admin"
        )
      end

      after { admin.destroy }

      it "locks account after 5 failed attempts" do
        5.times do
          admin.valid_for_authentication? { false }
        end
        admin.reload
        expect(admin.access_locked?).to be true
      end

      it "can be unlocked" do
        5.times { admin.valid_for_authentication? { false } }
        admin.reload
        expect(admin.access_locked?).to be true

        admin.unlock_access!
        expect(admin.access_locked?).to be false
      end
    end

    describe "timeoutable" do
      it "has a 30-minute timeout" do
        admin = build_admin
        expect(admin.timeout_in).to eq(30.minutes)
      end
    end

    describe "trackable" do
      it "has sign_in_count column" do
        expect(AdminUser.column_names).to include("sign_in_count")
      end

      it "has current_sign_in_at column" do
        expect(AdminUser.column_names).to include("current_sign_in_at")
      end
    end
  end
end
