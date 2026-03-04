# frozen_string_literal: true

class AddSecurityFieldsToAdminUsers < ActiveRecord::Migration[7.1]
  def change
    change_table :admin_users, bulk: true do |t|
      # Devise :lockable
      t.integer  :failed_attempts, default: 0, null: false
      t.string   :unlock_token
      t.datetime :locked_at

      # Devise :trackable
      t.integer  :sign_in_count,      default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip
    end

    add_index :admin_users, :unlock_token, unique: true
  end
end
