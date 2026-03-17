# frozen_string_literal: true

class CreateSettlementExceptions < ActiveRecord::Migration[7.1]
  def change
    create_table :settlement_exceptions do |t|
      t.references :settlement,     null: false, foreign_key: true
      t.string     :exception_type, null: false, comment: "payout_failed / amount_mismatch / merchant_frozen"
      t.text       :description
      t.string     :status,         null: false, default: "pending", comment: "pending / processing / resolved / ignored"
      t.bigint     :resolved_by,    comment: "处理人 admin_user_id"
      t.datetime   :resolved_at
      t.text       :resolution_note
      t.timestamps
    end

    add_index :settlement_exceptions, :status
    add_index :settlement_exceptions, :exception_type
  end
end
