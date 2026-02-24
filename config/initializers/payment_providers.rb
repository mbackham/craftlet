# frozen_string_literal: true
# config/initializers/payment_providers.rb
#
# Reads payment provider credentials from ENV and stores them on
# Rails.application.config.payment_providers so providers can reference them
# without coupling to ENV directly.

Rails.application.config.payment_providers = {
  wechat: {
    app_id:     ENV.fetch("WECHAT_APP_ID",     ""),
    mch_id:     ENV.fetch("WECHAT_MCH_ID",     ""),
    api_key:    ENV.fetch("WECHAT_API_KEY",     ""),
    cert_path:  ENV.fetch("WECHAT_CERT_PATH",   ""),
    notify_url: ENV.fetch("WECHAT_NOTIFY_URL",  "")
  },
  alipay: {
    app_id:      ENV.fetch("ALIPAY_APP_ID",      ""),
    private_key: ENV.fetch("ALIPAY_PRIVATE_KEY", ""),
    public_key:  ENV.fetch("ALIPAY_PUBLIC_KEY",  ""),
    notify_url:  ENV.fetch("ALIPAY_NOTIFY_URL",  "")
  }
}.freeze
