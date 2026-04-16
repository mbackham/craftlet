# frozen_string_literal: true

class DeviceToken < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :platform, presence: true, inclusion: { in: %w[ios android] }

  scope :ios, -> { where(platform: 'ios') }
  scope :android, -> { where(platform: 'android') }
end
