# frozen_string_literal: true

class CreateInvoices < ActiveRecord::Migration[7.1]
  def change
    create_table :invoices do |t|
      t.string     :invoice_no,          null: false, comment: "发票编号"
      t.references :settlement,          null: false, foreign_key: true
      t.references :merchant_profile,    null: false, foreign_key: true
      t.string     :invoice_type,        null: false, default: "normal", comment: "normal / special"
      t.decimal    :amount,              precision: 12, scale: 2, null: false
      t.string     :status,             null: false, default: "requested", comment: "发票状态"
      t.string     :title,              comment: "发票抬头"
      t.string     :tax_no,             comment: "纳税人识别号"
      t.string     :tracking_no,        comment: "快递单号"
      t.datetime   :shipped_at
      t.datetime   :received_at
      t.string     :rejected_reason,    limit: 500
      t.datetime   :requested_at
      t.datetime   :issued_at
      t.bigint     :issued_by,          comment: "开票人 admin_user_id"
      t.timestamps
    end

    add_index :invoices, :invoice_no, unique: true
    add_index :invoices, :status
  end
end
