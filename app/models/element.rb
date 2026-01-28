# frozen_string_literal: true

class Element < ApplicationRecord
  # === Constants ===
  STATUSES = %w[draft on_shelf off_shelf].freeze
  CATEGORIES = %w[background character prop effect font].freeze

  # === Validations ===
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  # === Scopes ===
  scope :draft, -> { where(status: 'draft') }
  scope :on_shelf, -> { where(status: 'on_shelf') }
  scope :off_shelf, -> { where(status: 'off_shelf') }

  # === Status Methods ===
  def draft?
    status == 'draft'
  end

  def on_shelf?
    status == 'on_shelf'
  end

  def off_shelf?
    status == 'off_shelf'
  end

  def can_shelf?
    draft? || off_shelf?
  end

  def can_unshelf?
    on_shelf?
  end

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

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id name category status price created_at updated_at shelved_at unshelved_at]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end
end
