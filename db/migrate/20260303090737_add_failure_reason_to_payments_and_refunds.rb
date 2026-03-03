class AddFailureReasonToPaymentsAndRefunds < ActiveRecord::Migration[7.1]
  def change
    add_column :payments, :failure_reason, :string, limit: 500
    add_column :refunds,  :failure_reason, :string, limit: 500
  end
end
