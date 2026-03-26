# frozen_string_literal: true

class AbTest < ApplicationRecord
  # === Constants ===
  STATUSES = %w[draft running paused completed].freeze

  # === Virtual Attributes ===
  attr_accessor :variants_json
  after_initialize :init_variants_json
  before_validation :parse_variants_json

  # === Validations ===
  validates :name, presence: true
  validates :test_key, presence: true, uniqueness: true,
            format: { with: /\A[a-z0-9_]+\z/, message: "只允许小写字母、数字和下划线" }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :traffic_percentage, numericality: { in: 0..100 }
  validate  :variants_format

  # === Scopes ===
  scope :draft,     -> { where(status: "draft") }
  scope :running,   -> { where(status: "running") }
  scope :paused,    -> { where(status: "paused") }
  scope :completed, -> { where(status: "completed") }

  # === Status Methods ===
  def draft?
    status == "draft"
  end

  def running?
    status == "running"
  end

  def paused?
    status == "paused"
  end

  def completed?
    status == "completed"
  end

  def can_start?
    draft? || paused?
  end

  def can_pause?
    running?
  end

  def can_complete?
    running? || paused?
  end

  # === Actions ===
  def start!
    return false unless can_start?

    update!(status: "running", start_at: start_at || Time.current)
  end

  def pause!
    return false unless can_pause?

    update!(status: "paused")
  end

  def complete!
    return false unless can_complete?

    update!(status: "completed", end_at: Time.current)
  end

  # === Display Helpers ===
  def status_label
    I18n.t("ab_test_statuses.#{status}", default: status.humanize)
  end

  def variants_summary
    return "无变体" if variants.blank?

    variants.map { |v| "#{v['name']}(#{v['weight']}%)" }.join(" / ")
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id name test_key status traffic_percentage start_at end_at created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end

  private

  def init_variants_json
    return if variants_json.present?

    default_variants = [{ "name" => "A", "weight" => 50, "config" => {} }, { "name" => "B", "weight" => 50, "config" => {} }]
    self.variants_json = JSON.pretty_generate(variants.presence || default_variants)
  end

  def parse_variants_json
    return if variants_json.blank? || !variants_json.is_a?(String)

    begin
      self.variants = JSON.parse(variants_json)
    rescue JSON::ParserError
      errors.add(:variants_json, I18n.t("admin.errors.invalid_json", default: "Invalid JSON format"))
    end
  end

  def variants_format
    return if variants.blank?

    unless variants.is_a?(Array) && variants.all? { |v| v.is_a?(Hash) && v["name"].present? }
      errors.add(:variants, "每个变体必须包含 name 字段")
    end
  end
end
