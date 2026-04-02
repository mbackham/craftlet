class EtlCleanRule < ApplicationRecord
  RULE_TYPES = %w[null_check range_check format_check enum_check custom].freeze
  ACTIONS = %w[skip fill_default transform flag].freeze

  has_many :etl_clean_logs, dependent: :destroy

  validates :name, presence: true
  validates :source_table, presence: true
  validates :target_field, presence: true
  validates :rule_type, presence: true, inclusion: { in: RULE_TYPES }
  validates :action, inclusion: { in: ACTIONS }

  scope :active, -> { where(is_active: true) }
  scope :for_table, ->(table) { where(source_table: table) }
  scope :ordered, -> { order(priority: :asc) }

  def self.ransackable_attributes(auth_object = nil)
    %w[name source_table target_field rule_type action is_active priority created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[etl_clean_logs]
  end
end
