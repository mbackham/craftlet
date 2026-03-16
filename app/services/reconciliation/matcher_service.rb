module Reconciliation
  class MatcherService
    # @param statement_record [Hash] { transaction_no: "...", order_no: "...", amount: 100.0, type: "payment|refund", date: "..." }
    def self.match(statement_record)
      type = statement_record[:type]
      
      system_record = find_system_record(statement_record)
      
      if system_record.nil?
        return { match_status: 'missing_in_system', system_amount: 0.0 }
      end

      # 金额匹配
      sys_amt = system_record.amount.to_f
      stmt_amt = statement_record[:amount].to_f
      
      if (sys_amt - stmt_amt).abs < 0.01
        { match_status: 'matched', system_amount: sys_amt }
      else
        { match_status: 'amount_mismatch', system_amount: sys_amt }
      end
    end

    private

    def self.find_system_record(record)
      if record[:type] == 'refund'
        # 查找退款记录 by provider_refund_no 或对应的 order_no
        refund = Refund.find_by(provider_refund_no: record[:transaction_no])
        unless refund
          order = Order.find_by(order_no: record[:order_no])
          refund = Refund.find_by(order_id: order.id) if order
        end
        refund
      else
        # 查找支付记录 by provider_trade_no 或对应的 order_no
        payment = Payment.find_by(provider_trade_no: record[:transaction_no])
        unless payment
          order = Order.find_by(order_no: record[:order_no])
          payment = Payment.find_by(order_id: order.id) if order
        end
        payment
      end
    end
  end
end
