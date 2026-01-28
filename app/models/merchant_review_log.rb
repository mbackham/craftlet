# frozen_string_literal: true

class MerchantReviewLog < ApplicationRecord
  # === Constants ===
  ACTIONS = %w[submit approve reject suspend unsuspend update].freeze

  # === Associations ===
  belongs_to :merchant_profile
  # Note: operator_admin_id is UUID, AdminUser uses bigint
  # Use custom operator method instead of belongs_to

  # === Validations ===
  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :note, presence: true, if: :requires_note?

  # === Scopes ===
  scope :recent, -> { order(created_at: :desc) }
  scope :approvals, -> { where(action: 'approve') }
  scope :rejections, -> { where(action: 'reject') }

  # === Query Methods ===
  def approval?
    action == 'approve'
  end

  def rejection?
    action == 'reject'
  end

  # === Display Helpers ===
  def action_label
    I18n.t("merchant_review_actions.#{action}", default: action.humanize)
  end

  def operator_display_name
    operator&.email || '系统'
  end

  # Custom operator lookup (UUID to bigint conversion)
  def operator
    return nil if operator_admin_id.blank?
    
    numeric_id = operator_admin_id.to_s.split('-').last.to_i
    AdminUser.find_by(id: numeric_id)
  end

  # Helper to format admin user ID as UUID for storage
  def self.format_admin_id_as_uuid(admin_user_id)
    sprintf('00000000-0000-0000-0000-%012d', admin_user_id.to_i)
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id action note created_at merchant_profile_id operator_admin_id]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[merchant_profile operator]
  end

  private

  def requires_note?
    action == 'reject'
  end
end
