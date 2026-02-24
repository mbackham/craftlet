class AddPayloadColumnsToPaymentsAndRefunds < ActiveRecord::Migration[7.1]
  def change
    add_column :payments, :request_payload,  :jsonb, default: {}, null: false
    add_column :payments, :response_payload, :jsonb, default: {}, null: false
    add_column :payments, :notify_payload,   :jsonb, default: {}, null: false

    add_column :refunds, :request_payload,   :jsonb, default: {}, null: false
    add_column :refunds, :response_payload,  :jsonb, default: {}, null: false
    add_column :refunds, :notify_payload,    :jsonb, default: {}, null: false
  end
end
