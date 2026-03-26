# frozen_string_literal: true

class Banner < ApplicationRecord
  include MultilingualFields

  # === Constants ===
  STATUSES = %w[draft active inactive].freeze
  PLACEMENTS = %w[home category detail].freeze

  # === Multilingual JSONB Fields ===
  multilingual :title

  # === Validations ===
  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :placement, presence: true, inclusion: { in: PLACEMENTS }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  # === Scopes ===
  scope :draft,    -> { where(status: "draft") }
  scope :active,   -> { where(status: "active") }
  scope :inactive, -> { where(status: "inactive") }
  scope :ordered,  -> { order(position: :asc, created_at: :desc) }
  scope :current,  -> {
    active.where("start_at IS NULL OR start_at <= ?", Time.current)
          .where("end_at IS NULL OR end_at > ?", Time.current)
  }

  # === Status Methods ===
  def draft?
    status == "draft"
  end

  def active?
    status == "active"
  end

  def inactive?
    status == "inactive"
  end

  def can_activate?
    draft? || inactive?
  end

  def can_deactivate?
    active?
  end

  # === Actions ===
  def activate!
    return false unless can_activate?

    update!(status: "active")
  end

  def deactivate!
    return false unless can_deactivate?

    update!(status: "inactive")
  end

  # === I18n Helpers ===
  def localized_title(locale = I18n.locale)
    title.is_a?(Hash) ? (title[locale.to_s] || title[I18n.default_locale.to_s] || title.values.first) : title
  end

  def status_label
    I18n.t("banner_statuses.#{status}", default: status.humanize)
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id status placement position start_at end_at created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end


end
