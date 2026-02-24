# frozen_string_literal: true

module Payments
  # Maps a payment channel string to the corresponding provider instance.
  #
  # Usage:
  #   provider = Payments::ProviderFactory.for("wechat")
  #   provider.create_payment(payment: payment)
  class ProviderFactory
    REGISTRY = {
      "wechat" => -> { WechatProvider.new },
      "alipay" => -> { AlipayProvider.new }
    }.freeze

    # @param channel [String] e.g. "wechat", "alipay"
    # @return [Payments::BaseProvider]
    # @raise [ArgumentError] if channel is unsupported
    def self.for(channel)
      factory = REGISTRY[channel.to_s]
      raise ArgumentError, "Unsupported payment channel: #{channel}" if factory.nil?

      factory.call
    end
  end
end
