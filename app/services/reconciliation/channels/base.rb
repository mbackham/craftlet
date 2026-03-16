module Reconciliation
  module Channels
    class Base
      # @param bank_statement [BankStatement]
      def initialize(bank_statement)
        @bank_statement = bank_statement
      end

      # 必须由子类实现
      # 返回格式: Array of Hashes
      # [{ transaction_no: '...', order_no: '...', amount: 100.0, type: 'payment|refund', date: '...' }]
      def parse
        raise NotImplementedError, "#{self.class} must implement #parse"
      end
    end
  end
end
