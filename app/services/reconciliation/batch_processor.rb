module Reconciliation
  class BatchProcessor
    def initialize(bank_statement)
      @bank_statement = bank_statement
    end

    def process!
      ActiveRecord::Base.transaction do
        # 1. 创建批次
        batch = ReconciliationBatch.create!(
          target_date: @bank_statement.statement_date,
          status: 'processing',
          channel: @bank_statement.channel,
          total_count: 0,
          matched_count: 0,
          mismatched_count: 0
        )
        
        @bank_statement.update!(status: 'processing')

        # 2. 解析账单
        records = StatementParser.parse(@bank_statement)
        
        # 3. 对账
        total = 0
        matched = 0
        mismatched = 0

        # TODO: 还需要反向检查系统里有，但账单里没有的记录 (missing_in_statement)
        # 这里为了简化，仅实现单向比对：以账单为基准匹配系统

        records.each do |record|
          total += 1
          match_result = MatcherService.match(record)
          
          # 创建明细
          ReconciliationDetail.create!(
            reconciliation_batch: batch,
            transaction_no: record[:transaction_no],
            order_no: record[:order_no],
            reconciliation_type: record[:type],
            statement_amount: record[:amount],
            system_amount: match_result[:system_amount],
            match_status: match_result[:match_status],
            process_status: match_result[:match_status] == 'matched' ? 'ignored' : 'pending'
          )
          
          if match_result[:match_status] == 'matched'
            matched += 1
          else
            mismatched += 1
          end
        end

        # 反向对账：检查系统中有但账单中没有的记录 (missing_in_statement)
        statement_order_nos = records.select { |r| r[:type] == 'payment' }.map { |r| r[:order_no] }.compact
        statement_refund_nos = records.select { |r| r[:type] == 'refund' }.map { |r| r[:order_no] }.compact

        # 查找当日系统内的支付记录，但账单中未出现
        system_payments = Payment.joins(:order)
                                .where(orders: { order_no: Order.select(:order_no) })
                                .where(status: 'paid')
                                .where(paid_at: @bank_statement.statement_date.all_day)
        system_payments.each do |payment|
          order = payment.order
          next if statement_order_nos.include?(order.order_no)

          total += 1
          mismatched += 1
          ReconciliationDetail.create!(
            reconciliation_batch: batch,
            transaction_no: payment.provider_trade_no,
            order_no: order.order_no,
            reconciliation_type: 'payment',
            system_amount: payment.amount,
            statement_amount: 0,
            match_status: 'missing_in_statement',
            process_status: 'pending'
          )
        end

        # 查找当日系统内的退款记录，但账单中未出现
        system_refunds = Refund.joins(:order)
                               .where(status: 'succeeded')
                               .where(succeeded_at: @bank_statement.statement_date.all_day)
        system_refunds.each do |refund|
          order = refund.order
          next if statement_refund_nos.include?(order.order_no)

          total += 1
          mismatched += 1
          ReconciliationDetail.create!(
            reconciliation_batch: batch,
            transaction_no: refund.provider_refund_no,
            order_no: order.order_no,
            reconciliation_type: 'refund',
            system_amount: refund.amount,
            statement_amount: 0,
            match_status: 'missing_in_statement',
            process_status: 'pending'
          )
        end

        # 4. 更新批次结果
        batch.update!(
          total_count: total,
          matched_count: matched,
          mismatched_count: mismatched,
          status: 'completed'
        )
        @bank_statement.update!(status: 'processed')
        
        batch
      end
    rescue => e
      @bank_statement.update(status: 'failed')
      # 可以考虑记录日志等
      raise e
    end
  end
end
