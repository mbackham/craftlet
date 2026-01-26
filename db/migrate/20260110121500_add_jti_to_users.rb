require "securerandom"

class AddJtiToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :jti, :string, null: false, default: ""

    reversible do |dir|
      dir.up do
        user_class = Class.new(ActiveRecord::Base) do
          self.table_name = "users"
        end
        user_class.reset_column_information

        user_class.find_each do |user|
          user.update_column(:jti, SecureRandom.uuid)
        end
      end
    end

    change_column_default :users, :jti, nil
    add_index :users, :jti, unique: true
  end
end
