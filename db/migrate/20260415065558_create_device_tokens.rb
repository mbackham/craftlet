class CreateDeviceTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :device_tokens do |t|
      t.bigint :user_id, null: false
      t.string :token, null: false
      t.string :platform, null: false, comment: 'ios / android'

      t.timestamps
    end

    add_index :device_tokens, :user_id
    add_index :device_tokens, :token, unique: true
    add_index :device_tokens, :platform
  end
end
