class CreateDwDimTime < ActiveRecord::Migration[7.1]
  def change
    create_table :dw_dim_time do |t|
      t.date    :date_value, null: false
      t.integer :year
      t.integer :quarter
      t.integer :month
      t.integer :week_of_year
      t.integer :day_of_week
      t.boolean :is_weekend
      t.boolean :is_holiday, default: false
      t.string  :holiday_name
    end

    add_index :dw_dim_time, :date_value, unique: true
  end
end
