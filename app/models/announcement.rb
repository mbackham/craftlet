# frozen_string_literal: true

class Announcement < ApplicationRecord
  include MultilingualFields

  # === Constants ===
  STATUSES = %w[draft published archived].freeze
  TYPES = %w[info warning maintenance].freeze

  # === Multilingual JSONB Fields ===
  multilingual :title, :content

  # === Validations ===
  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :announcement_type, presence: true, inclusion: { in: TYPES }

  # === Scopes ===
  scope :draft,     -> { where(status: "draft") }
  scope :published, -> { where(status: "published") }
  scope :archived,  -> { where(status: "archived") }
  scope :pinned,    -> { where(is_pinned: true) }
  scope :current,   -> {
    published.where("expire_at IS NULL OR expire_at > ?", Time.current)
  }
  scope :ordered, -> { order(is_pinned: :desc, created_at: :desc) }

  # === Status Methods ===
  def draft?
    status == "draft"
  end

  def published?
    status == "published"
  end

  def archived?
    status == "archived"
  end

  def can_publish?
    draft?
  end

  def can_archive?
    published?
  end

  # === Actions ===
  def publish!
    return false unless can_publish?

    update!(status: "published")
  end

  def archive!
    return false unless can_archive?

    update!(status: "archived")
  end

  # === I18n Helpers ===
  def localized_title(locale = I18n.locale)
    title.is_a?(Hash) ? (title[locale.to_s] || title[I18n.default_locale.to_s] || title.values.first) : title
  end

  def localized_content(locale = I18n.locale)
    content.is_a?(Hash) ? (content[locale.to_s] || content[I18n.default_locale.to_s] || content.values.first) : content
  end

  def status_label
    I18n.t("announcement_statuses.#{status}", default: status.humanize)
  end

  def type_label
    I18n.t("announcement_types.#{announcement_type}", default: announcement_type.humanize)
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id status announcement_type is_pinned publish_at expire_at created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end
end
