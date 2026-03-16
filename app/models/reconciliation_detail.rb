class ReconciliationDetail < ApplicationRecord
  belongs_to :reconciliation_batch
  belongs_to :handler_admin, class_name: 'AdminUser', foreign_key: 'handler_admin_id', optional: true

  enum match_status: { matched: 'matched', amount_mismatch: 'amount_mismatch', missing_in_system: 'missing_in_system', missing_in_statement: 'missing_in_statement' }
  enum process_status: { pending: 'pending', claimed: 'claimed', adjusted: 'adjusted', ignored: 'ignored' }
  enum reconciliation_type: { payment: 'payment', refund: 'refund' }

  def self.ransackable_attributes(auth_object = nil)
    ["adjustment_reason", "created_at", "error_message", "handler_admin_id", "id", "match_status", "order_no", "process_status", "reconciliation_batch_id", "reconciliation_type", "statement_amount", "system_amount", "transaction_no", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["handler_admin", "reconciliation_batch"]
  end
end
