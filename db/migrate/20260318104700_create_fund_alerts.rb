class CreateFundAlerts < ActiveRecord::Migration[7.1]
  def change
    create_table :fund_alerts do |t|
      t.string   :alert_type,    null: false               # payment / refund / settlement
      t.string   :subject_type,  null: false               # Payment / Refund / Settlement
      t.bigint   :subject_id,    null: false
      t.decimal  :amount,        precision: 12, scale: 2, null: false
      t.decimal  :threshold,     precision: 12, scale: 2, null: false
      t.string   :status,        null: false, default: "pending"  # pending / acknowledged / ignored
      t.bigint   :handler_admin_id
      t.text     :note
      t.datetime :acknowledged_at

      t.timestamps
    end

    add_index :fund_alerts, [:subject_type, :subject_id]
    add_index :fund_alerts, :status
    add_index :fund_alerts, :created_at
    add_index :fund_alerts, :alert_type
  end
end
