# frozen_string_literal: true

class BraceletConfig < ApplicationRecord
  STATUSES    = %w[draft saved ordered].freeze
  WRIST_SIZES = %w[S M L XL free_size].freeze
  KNOT_STYLES = %w[single_knot double_knot adjustable].freeze

  # === Associations ===
  belongs_to :user
  belongs_to :string_element, class_name: 'Element', optional: true

  # === Validations ===
  validates :name,   presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :bead_items, bead_items: true
  validates :wrist_size,  inclusion: { in: WRIST_SIZES }, allow_nil: true
  validates :knot_style,  inclusion: { in: KNOT_STYLES }, allow_nil: true
  validates :total_beads, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :estimated_length_mm, numericality: { greater_than: 0 }, allow_nil: true
  validate  :string_element_must_be_string_type

  # === Callbacks ===
  before_save :sync_total_beads

  # === Scopes ===
  scope :draft,   -> { where(status: 'draft') }
  scope :saved,   -> { where(status: 'saved') }
  scope :ordered, -> { where(status: 'ordered') }

  # === Status Methods ===
  def draft?   = status == 'draft'
  def saved?   = status == 'saved'
  def ordered? = status == 'ordered'

  def save!
    return false if ordered?
    update!(status: 'saved', saved_at: Time.current)
  end

  # 下单时调用，锁定当前价格快照
  def snapshot_prices!
    element_ids = bead_items.pluck('element_id').compact + [string_element_id].compact
    elements    = Element.where(id: element_ids).index_by(&:id)

    snapshot = bead_items.each_with_object({}) do |item, h|
      el = elements[item['element_id']]
      h[item['element_id'].to_s] = el&.price&.to_s
    end
    snapshot['string_element_id'] = elements[string_element_id]&.price&.to_s if string_element_id

    total = bead_items.sum do |item|
      qty  = item['quantity'].to_i
      el   = elements[item['element_id']]
      qty * el.price.to_f
    end
    total += elements[string_element_id]&.price.to_f if string_element_id

    snapshot['total'] = total.to_s
    update!(price_snapshot: snapshot, status: 'ordered')
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id user_id name status wrist_size knot_style total_beads
       estimated_length_mm string_element_id created_at updated_at saved_at]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end

  private

  def sync_total_beads
    self.total_beads = bead_items.sum { |item| item['quantity'].to_i }
  end

  def string_element_must_be_string_type
    return unless string_element
    errors.add(:string_element, :wrong_type) unless string_element.string?
  end
end
