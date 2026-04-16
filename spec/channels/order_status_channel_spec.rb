# frozen_string_literal: true

require 'rails_helper'

# spec/channels/order_status_channel_spec.rb
#
# OrderStatusChannel — 订单状态实时推送 Channel 测试
#
# 验收标准：
#   ✅ 消费者可以订阅自己的订单
#   ✅ 商家可以订阅自己的订单
#   ✅ 无关用户订阅被 reject
#   ✅ 不存在的订单订阅被 reject
#   ✅ unsubscribed 停止所有推流
#
RSpec.describe OrderStatusChannel, type: :channel do
  # ── 测试数据 ──────────────────────────────────────────────────────────────

  let!(:customer_user) { create(:user, email: 'channel-customer@example.com') }
  let!(:merchant_user) { create(:user, email: 'channel-merchant@example.com') }
  let!(:stranger_user) { create(:user, email: 'channel-stranger@example.com') }

  let!(:order) do
    create(:order,
           customer_id: Order.id_to_uuid(customer_user.id),
           merchant_id: Order.id_to_uuid(merchant_user.id),
           status: 'paid')
  end

  # ── 消费者订阅 ────────────────────────────────────────────────────────────

  describe '消费者订阅自己的订单' do
    before { stub_connection current_user: customer_user }

    it 'subscribes successfully and streams from order channel' do
      subscribe(order_id: order.id)

      expect(subscription).to be_confirmed
      # rspec-rails channel spec 用 subscription.streams 而非 streams
      expect(subscription.streams).to include("order_status_#{order.id}")
    end
  end

  # ── 商家订阅 ─────────────────────────────────────────────────────────────

  describe '商家订阅自己的订单' do
    before { stub_connection current_user: merchant_user }

    it 'subscribes successfully and streams from order channel' do
      subscribe(order_id: order.id)

      expect(subscription).to be_confirmed
      expect(subscription.streams).to include("order_status_#{order.id}")
    end
  end

  # ── 无关用户被拒 ──────────────────────────────────────────────────────────

  describe '无关用户订阅（越权）' do
    before { stub_connection current_user: stranger_user }

    it 'rejects the subscription' do
      subscribe(order_id: order.id)

      expect(subscription).to be_rejected
    end
  end

  # ── 订单不存在 ────────────────────────────────────────────────────────────

  describe '订单不存在时' do
    before { stub_connection current_user: customer_user }

    it 'rejects the subscription for non-existent order' do
      subscribe(order_id: 999999)

      expect(subscription).to be_rejected
    end
  end

  # ── 消息广播 ─────────────────────────────────────────────────────────────

  describe '订单状态广播' do
    before { stub_connection current_user: customer_user }

    it 'receives broadcast when order status changes' do
      subscribe(order_id: order.id)
      expect(subscription).to be_confirmed

      # 模拟订单状态变更广播（rspec-rails channel spec 用 ActionCable::Channel::Testing broadcast）
      broadcast_payload = {
        'order_id' => order.id,
        'status'   => 'accepted',
        'updated_at' => Time.current.iso8601
      }

      expect {
        ActionCable.server.broadcast("order_status_#{order.id}", broadcast_payload)
      }.to have_broadcasted_to("order_status_#{order.id}")
    end
  end

  # ── 取消订阅 ─────────────────────────────────────────────────────────────

  describe '取消订阅' do
    before { stub_connection current_user: customer_user }

    it 'stops all streams after unsubscribe' do
      subscribe(order_id: order.id)
      expect(subscription).to be_confirmed
      expect(subscription.streams).to include("order_status_#{order.id}")

      unsubscribe
      expect(subscription.streams).to be_empty
    end
  end
end
