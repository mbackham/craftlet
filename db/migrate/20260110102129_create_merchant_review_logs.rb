class CreateMerchantReviewLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :merchant_review_logs do |t|
      t.references :merchant_profile, null: false, foreign_key: true
      t.string :action, null: false
      t.uuid :operator_admin_id, null: false
      t.text :note

      t.timestamps
    end

    add_index :merchant_review_logs, :operator_admin_id
    add_index :merchant_review_logs, :action
  end
end
