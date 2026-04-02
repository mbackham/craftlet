class DwDimTime < ApplicationRecord
  scope :weekdays, -> { where(is_weekend: false) }
  scope :weekends, -> { where(is_weekend: true) }
  scope :holidays, -> { where(is_holiday: true) }

  def self.find_or_create_for(date)
    date = date.to_date
    find_or_create_by!(date_value: date) do |t|
      t.year         = date.year
      t.quarter      = (date.month / 3.0).ceil
      t.month        = date.month
      t.week_of_year = date.cweek
      t.day_of_week  = date.wday
      t.is_weekend   = date.saturday? || date.sunday?
    end
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[date_value year quarter month week_of_year day_of_week is_weekend is_holiday]
  end
end
