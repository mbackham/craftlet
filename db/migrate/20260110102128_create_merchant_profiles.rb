class CreateMerchantProfiles < ActiveRecord::Migration[7.1]
  def change
    create_table :merchant_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :shop_name, null: false
      t.string :status, null: false, default: "pending"
      t.string :address_province
      t.string :address_city
      t.string :address_district
      t.string :address_detail
      t.string :license_file_key
      t.string :idcard_front_key
      t.string :idcard_back_key
      t.text :bank_account_name_ciphertext
      t.text :bank_account_no_ciphertext
      t.string :bank_account_no_bidx
      t.string :bank_name
      t.string :bank_branch
      t.decimal :deposit_amount, precision: 12, scale: 2
      t.datetime :approved_at
      t.uuid :approved_by_admin_id
      t.datetime :rejected_at
      t.uuid :rejected_by_admin_id
      t.text :reject_reason

      t.timestamps
    end

    add_index :merchant_profiles, :status
    add_index :merchant_profiles, :bank_account_no_bidx, unique: true
    add_index :merchant_profiles, :approved_by_admin_id
    add_index :merchant_profiles, :rejected_by_admin_id
  end
end
