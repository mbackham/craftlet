# frozen_string_literal: true

class FaqCategory < ApplicationRecord
  include MultilingualFields

  # === Associations ===
  has_many :faqs, dependent: :destroy

  # === Multilingual JSONB Fields ===
  multilingual :name

  # === Validations ===
  validates :name, presence: true
  validates :slug, uniqueness: true, allow_blank: true

  # === Scopes ===
  scope :active,  -> { where(is_active: true) }
  scope :ordered, -> { order(sort: :asc, created_at: :asc) }

  # === I18n Helpers ===
  def localized_name(locale = I18n.locale)
    name.is_a?(Hash) ? (name[locale.to_s] || name[I18n.default_locale.to_s] || name.values.first) : name
  end

  def display_name
    localized_name
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id slug sort is_active created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[faqs]
  end
end
