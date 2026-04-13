# frozen_string_literal: true

require 'rails_helper'

# UuidIdentity concern 单元测试
# Unit tests for the UuidIdentity concern
#
# 验证 UUID <-> bigint 双向转换的正确性，以及通过 UUID 列查找 User / AdminUser 的行为。
# Validates bidirectional UUID <-> bigint conversion and UUID-column-based User/AdminUser lookups.
#
RSpec.describe UuidIdentity do
  # 使用 Order 作为载体（已 include UuidIdentity）
  # Using Order as the host class (already includes UuidIdentity)
  let(:host_class) { Order }

  # ---------------------------------------------------------------------------
  # id_to_uuid — bigint → UUID 字符串 / bigint → UUID string
  # ---------------------------------------------------------------------------
  describe '.id_to_uuid' do
    it 'encodes a positive integer ID as a zero-padded UUID string' do
      expect(host_class.id_to_uuid(42)).to eq('00000000-0000-0000-0000-000000000042')
    end

    it 'encodes a large integer ID correctly' do
      expect(host_class.id_to_uuid(999_999_999_999)).to eq('00000000-0000-0000-0000-999999999999')
    end

    it 'accepts a string representation of an integer' do
      expect(host_class.id_to_uuid('7')).to eq('00000000-0000-0000-0000-000000000007')
    end

    it 'returns nil for nil input' do
      expect(host_class.id_to_uuid(nil)).to be_nil
    end

    it 'returns nil for blank string input' do
      expect(host_class.id_to_uuid('')).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # uuid_to_id — UUID 字符串 → bigint / UUID string → bigint
  # ---------------------------------------------------------------------------
  describe '.uuid_to_id' do
    it 'decodes a UUID string back to the original numeric ID' do
      expect(host_class.uuid_to_id('00000000-0000-0000-0000-000000000042')).to eq(42)
    end

    it 'decodes a large numeric ID correctly' do
      expect(host_class.uuid_to_id('00000000-0000-0000-0000-999999999999')).to eq(999_999_999_999)
    end

    it 'returns nil for nil input' do
      expect(host_class.uuid_to_id(nil)).to be_nil
    end

    it 'returns nil for blank string input' do
      expect(host_class.uuid_to_id('')).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # 往返一致性 / Round-trip consistency
  # ---------------------------------------------------------------------------
  describe 'round-trip encoding' do
    it 'encodes and decodes back to the original ID (small ID)' do
      original_id = 1
      uuid = host_class.id_to_uuid(original_id)
      expect(host_class.uuid_to_id(uuid)).to eq(original_id)
    end

    it 'encodes and decodes back to the original ID (large ID)' do
      original_id = 123_456_789
      uuid = host_class.id_to_uuid(original_id)
      expect(host_class.uuid_to_id(uuid)).to eq(original_id)
    end
  end

  # ---------------------------------------------------------------------------
  # find_user_by_uuid — 通过 UUID 列值查找 User
  # find_user_by_uuid — Finds User by UUID-encoded column value
  # ---------------------------------------------------------------------------
  describe '.find_user_by_uuid' do
    context 'when a User with the encoded ID exists' do
      let!(:user) { create(:user) }

      it 'returns the correct User' do
        uuid = host_class.id_to_uuid(user.id)
        expect(host_class.find_user_by_uuid(uuid)).to eq(user)
      end
    end

    context 'when no User matches the encoded ID' do
      it 'returns nil for a non-existent ID' do
        uuid = host_class.id_to_uuid(999_999_998)
        expect(host_class.find_user_by_uuid(uuid)).to be_nil
      end
    end

    context 'when the UUID value is blank' do
      it 'returns nil for nil' do
        expect(host_class.find_user_by_uuid(nil)).to be_nil
      end

      it 'returns nil for empty string' do
        expect(host_class.find_user_by_uuid('')).to be_nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # find_admin_by_uuid — 通过 UUID 列值查找 AdminUser
  # find_admin_by_uuid — Finds AdminUser by UUID-encoded column value
  # ---------------------------------------------------------------------------
  describe '.find_admin_by_uuid' do
    context 'when an AdminUser with the encoded ID exists' do
      # AdminUser requires a strong password (12+ chars, mixed case, digits, special chars)
      # AdminUser 需要强密码（12 位以上，大小写混合，含数字和特殊字符）
      let!(:admin) { create(:admin_user, password: 'Str0ng!Pass#99', password_confirmation: 'Str0ng!Pass#99') }

      it 'returns the correct AdminUser' do
        uuid = host_class.id_to_uuid(admin.id)
        expect(host_class.find_admin_by_uuid(uuid)).to eq(admin)
      end
    end

    context 'when no AdminUser matches the encoded ID' do
      it 'returns nil for a non-existent ID' do
        uuid = host_class.id_to_uuid(999_999_997)
        expect(host_class.find_admin_by_uuid(uuid)).to be_nil
      end
    end

    context 'when the UUID value is blank' do
      it 'returns nil for nil' do
        expect(host_class.find_admin_by_uuid(nil)).to be_nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Order 模型集成验证（消除旧 hack 后的行为验证）
  # Order model integration — validates post-refactor behavior
  # ---------------------------------------------------------------------------
  describe 'Order integration' do
    let!(:customer) { create(:user) }
    let!(:merchant) { create(:user) }

    describe '#customer' do
      it 'resolves to the correct User via UUID-encoded customer_id' do
        order = Order.new(customer_id: Order.id_to_uuid(customer.id))
        expect(order.customer).to eq(customer)
      end

      it 'is aliased as #customer_user (backward-compat for ActiveAdmin)' do
        order = Order.new(customer_id: Order.id_to_uuid(customer.id))
        expect(order.customer_user).to eq(customer)
      end
    end

    describe '#merchant' do
      it 'resolves to the correct User via UUID-encoded merchant_id' do
        order = Order.new(merchant_id: Order.id_to_uuid(merchant.id))
        expect(order.merchant).to eq(merchant)
      end

      it 'is aliased as #merchant_user (backward-compat for ActiveAdmin)' do
        order = Order.new(merchant_id: Order.id_to_uuid(merchant.id))
        expect(order.merchant_user).to eq(merchant)
      end
    end

    describe '#customer= setter' do
      it 'stores the UUID-encoded ID in customer_id' do
        order = Order.new
        order.customer = customer
        expect(order.customer_id).to eq(Order.id_to_uuid(customer.id))
      end
    end

    describe '#merchant= setter' do
      it 'stores the UUID-encoded ID in merchant_id' do
        order = Order.new
        order.merchant = merchant
        expect(order.merchant_id).to eq(Order.id_to_uuid(merchant.id))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Bid 模型集成验证 / Bid model integration
  # ---------------------------------------------------------------------------
  describe 'Bid integration' do
    let!(:user) { create(:user) }

    describe '#bidder' do
      it 'resolves to the correct User via UUID-encoded bidder_id' do
        bid = Bid.new(bidder_id: Bid.id_to_uuid(user.id))
        expect(bid.bidder).to eq(user)
      end
    end

    describe '#bidder= setter' do
      it 'stores the UUID-encoded ID in bidder_id' do
        bid = Bid.new
        bid.bidder = user
        expect(bid.bidder_id).to eq(Bid.id_to_uuid(user.id))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # User#customer_orders / #merchant_orders 修复验证
  #
  # 背景 / Background:
  #   has_many :customer_orders, foreign_key: "customer_id" 生成的 SQL 为：
  #     WHERE orders.customer_id = <bigint>
  #   但实际数据库中 customer_id 存的是 UUID 格式，所以永远返回空集。
  #   必须改为实例方法，手动注入 UUID 格式的 id。
  #
  #   has_many :customer_orders, foreign_key: "customer_id" generates:
  #     WHERE orders.customer_id = <bigint>
  #   But the DB stores customer_id as a UUID string, so it always returns empty.
  #   Fixed by replacing with instance methods that inject UUID-encoded ids.
  # ---------------------------------------------------------------------------
  describe 'User#customer_orders and #merchant_orders' do
    let!(:customer) { create(:user) }
    let!(:merchant) { create(:user) }

    before do
      # 用正确的 UUID 格式写入 customer_id / merchant_id
      # Write customer_id / merchant_id in the correct UUID-encoded format
      Order.create!(
        order_no: "TEST-CUST-#{SecureRandom.hex(4)}",
        customer_id: Order.id_to_uuid(customer.id),
        merchant_id: Order.id_to_uuid(merchant.id),
        status: 'created',
        total_amount: 100,
        currency: 'CNY'
      )
    end

    describe '#customer_orders' do
      it 'returns orders where the user is the customer' do
        expect(customer.customer_orders.count).to eq(1)
      end

      it 'does NOT return orders where the user is the merchant' do
        expect(merchant.customer_orders.count).to eq(0)
      end

      it 'returns an ActiveRecord::Relation that supports chaining' do
        expect(customer.customer_orders.where(status: 'created').count).to eq(1)
        expect(customer.customer_orders.where(status: 'paid').count).to eq(0)
      end

      it 'is NOT affected by has_many bigint mismatch (regression guard)' do
        # 若仍使用 has_many foreign_key 查询，SQL 会传入 bigint，永远返回空
        # If has_many were still used, SQL would pass bigint → always empty
        expect(customer.customer_orders).not_to be_empty
      end
    end

    describe '#merchant_orders' do
      it 'returns orders where the user is the merchant' do
        expect(merchant.merchant_orders.count).to eq(1)
      end

      it 'does NOT return orders where the user is the customer' do
        expect(customer.merchant_orders.count).to eq(0)
      end

      it 'returns an ActiveRecord::Relation that supports chaining' do
        expect(merchant.merchant_orders.where(status: 'created').count).to eq(1)
        expect(merchant.merchant_orders.where(status: 'paid').count).to eq(0)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 全局检查：确认所有旧 hack 代码已消除
  # Global check: confirms all old hack code has been eliminated
  # ---------------------------------------------------------------------------
  describe 'legacy hack elimination' do
    it 'has no remaining split(\'-\').last.to_i pattern in model files (outside comments)' do
      model_files = Dir.glob(Rails.root.join('app/models/**/*.rb'))
      hack_pattern = /split\('-'\)\.last\.to_i/

      offending_files = model_files.reject do |file|
        # 排除 uuid_identity.rb 本身（spec 中的示例代码在注释里）
        # Exclude uuid_identity.rb itself (the pattern appears in comments there)
        file.end_with?('uuid_identity.rb')
      end.select do |file|
        # 只检查非注释行（不以 # 开头的行）
        # Only check non-comment lines (lines not starting with #)
        File.readlines(file).any? do |line|
          line !~ /^\s*#/ && line.match?(hack_pattern)
        end
      end

      expect(offending_files).to be_empty,
        "Found legacy UUID hack in: #{offending_files.map { |f| f.sub(Rails.root.to_s + '/', '') }.join(', ')}"
    end
  end
end
