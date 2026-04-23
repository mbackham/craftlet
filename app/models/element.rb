# frozen_string_literal: true

class Element < ApplicationRecord
  # === Constants ===
  STATUSES = %w[draft on_shelf off_shelf].freeze
  CATEGORIES = %w[background character prop effect font].freeze

  # 元素类型：bead=珠子, string=绳子, other=其他通用素材
  ELEMENT_TYPES = %w[bead string other].freeze

  # 材质类型（珠子+绳子共用，字段含义随 element_type 而不同）
  MATERIAL_TYPES = %w[
    wood glass hetian_jade jadeite agate crystal amber coral
    lapis turquoise obsidian bodhi bone metal ceramic resin fabric other
  ].freeze

  # 表面工艺
  FINISH_TYPES = %w[matte glossy frosted carved polished].freeze

  # === Associations ===
  has_many :bracelet_config_bead_items,
           class_name: 'BraceletConfig',
           foreign_key: :string_element_id,
           dependent: :nullify,
           inverse_of: :string_element

  # === Validations ===
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :element_type, inclusion: { in: ELEMENT_TYPES }, allow_nil: true
  validates :material_type, inclusion: { in: MATERIAL_TYPES }, allow_nil: true
  validates :finish_type, inclusion: { in: FINISH_TYPES }, allow_nil: true
  validates :size_mm, numericality: { greater_than_or_equal_to: 0.01 }, allow_nil: true
  validates :weight_g, numericality: { greater_than_or_equal_to: 0.001 }, allow_nil: true
  validates :hole_diameter_mm, numericality: { greater_than_or_equal_to: 0.01 }, allow_nil: true
  validates :color_hex, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_nil: true

  # === Scopes ===
  scope :draft,      -> { where(status: 'draft') }
  scope :on_shelf,   -> { where(status: 'on_shelf') }
  scope :off_shelf,  -> { where(status: 'off_shelf') }
  scope :beads,      -> { where(element_type: 'bead') }
  scope :strings,    -> { where(element_type: 'string') }
  scope :by_material, ->(type) { where(material_type: type) }
  scope :natural,    -> { where(is_natural: true) }

  # === Status Methods ===
  def draft?    = status == 'draft'
  def on_shelf? = status == 'on_shelf'
  def off_shelf? = status == 'off_shelf'
  def bead?     = element_type == 'bead'
  def string?   = element_type == 'string'
  def can_shelf?   = draft? || off_shelf?
  def can_unshelf? = on_shelf?

  # === Actions ===
  def shelf!
    return false unless can_shelf?
    update!(status: 'on_shelf', shelved_at: Time.current)
  end

  def unshelf!
    return false unless can_unshelf?
    update!(status: 'off_shelf', unshelved_at: Time.current)
  end

  # === Display Helpers ===
  def status_label
    I18n.t("element_statuses.#{status}", default: status.humanize)
  end

  def element_type_label
    I18n.t("element_types.#{element_type}", default: element_type&.humanize)
  end

  def material_type_label
    I18n.t("material_types.#{material_type}", default: material_type&.humanize)
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id name category element_type material_type finish_type
      color_hex color_name size_mm weight_g is_natural origin_region
      status price created_at updated_at shelved_at unshelved_at
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end
end
