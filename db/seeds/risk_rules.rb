# frozen_string_literal: true

# Seed 3 built-in risk rules
# Run: rails runner db/seeds/risk_rules.rb

rules = [
  {
    code:        "high_freq_refund",
    name:        "高频退款申请",
    description: "同一用户在短时间内多次申请退款，可能存在恶意退款行为",
    category:    "refund",
    severity:    "high",
    params:      { window_minutes: 60, threshold: 3 },
    enabled:     true
  },
  {
    code:        "high_amount_refund",
    name:        "高金额退款",
    description: "单笔退款金额超过设定阈值，需人工审核",
    category:    "refund",
    severity:    "medium",
    params:      { amount_threshold: 1000 },
    enabled:     true
  },
  {
    code:        "merchant_bid_spam",
    name:        "商家异常竞标",
    description: "同一商家短时间内大量竞标或撤回，可能存在刷单行为",
    category:    "merchant",
    severity:    "high",
    params:      { window_minutes: 30, threshold: 10 },
    enabled:     true
  },
  {
    code:        "frequent_refund",
    name:        "同卡/同支付频繁退款",
    description: "同一笔支付在短时间内多次发起退款，可能存在欺诈或异常退款行为",
    category:    "refund",
    severity:    "high",
    params:      { max_count: 3, window_days: 7 },
    enabled:     true
  }
]

rules.each do |attrs|
  rule = RiskRule.find_or_initialize_by(code: attrs[:code])
  rule.assign_attributes(attrs)
  if rule.save
    puts "✅ Rule '#{rule.code}' — #{rule.new_record? ? 'created' : 'updated'}"
  else
    puts "❌ Rule '#{rule.code}' failed: #{rule.errors.full_messages.join(', ')}"
  end
end

puts "\nTotal risk rules: #{RiskRule.count}"
