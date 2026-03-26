# frozen_string_literal: true

class Faq < ApplicationRecord
  include MultilingualFields

  # === Associations ===
  belongs_to :faq_category, optional: true

  # === Multilingual JSONB Fields ===
  multilingual :question, :answer

  # === Validations ===
  validates :question, presence: true
  validates :answer, presence: true

  # === Scopes ===
  scope :active,  -> { where(is_active: true) }
  scope :ordered, -> { order(sort: :asc, created_at: :asc) }

  # === I18n Helpers ===
  def localized_question(locale = I18n.locale)
    question.is_a?(Hash) ? (question[locale.to_s] || question[I18n.default_locale.to_s] || question.values.first) : question
  end

  def localized_answer(locale = I18n.locale)
    answer.is_a?(Hash) ? (answer[locale.to_s] || answer[I18n.default_locale.to_s] || answer.values.first) : answer
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id faq_category_id sort is_active created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[faq_category]
  end
end
