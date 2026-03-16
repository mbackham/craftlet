require 'csv'

module Reconciliation
  module Channels
    class BankCsv < Base
      def parse
        return [] unless @bank_statement.file.attached?
        
        file_content = @bank_statement.file.download
        parsed_data = []

        # 简单的 CSV 解析示例，假设行：交易单号, 商户单号, 金额, 类型(payment/refund), 日期
        # 实际项目中需根据银行真实的CSV格式调整列索引
        CSV.parse(file_content, headers: true) do |row|
          parsed_data << {
            transaction_no: row['transaction_no'].to_s.strip,
            order_no: row['order_no'].to_s.strip,
            amount: row['amount'].to_f,
            type: row['type'].to_s.strip.downcase, # 'payment' or 'refund'
            date: row['date']
          }
        end

        parsed_data
      end
    end
  end
end
