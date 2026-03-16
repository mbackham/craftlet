module Reconciliation
  class StatementParser
    def self.parse(bank_statement)
      case bank_statement.channel
      when 'bank'
        Channels::BankCsv.new(bank_statement).parse
      when 'alipay'
        Channels::Alipay.new(bank_statement).parse
      when 'wechat'
        Channels::Wechat.new(bank_statement).parse
      else
        raise ArgumentError, "未知的渠道: #{bank_statement.channel}"
      end
    end
  end
end
