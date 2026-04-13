# frozen_string_literal: true

class MerchantReviewLog < ApplicationRecord
  include UuidIdentity

  # === Constants ===
  ACTIONS = %w[submit approve reject suspend unsuspend update].freeze

  # === Associations ===
  belongs_to :merchant_profile
  # Note: operator_admin_id is a UUID-encoded bigint ID (see UuidIdentity concern)

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

  # === Operator Lookup (via UuidIdentity) ===
  # operator_admin_id 存储格式：00000000-0000-0000-0000-{12 位 bigint ID}
  # Stored as: 00000000-0000-0000-0000-{12-digit bigint ID}
  def operator
    @operator ||= self.class.find_admin_by_uuid(operator_admin_id)
  end

  # 向下兼容：format_admin_id_as_uuid 委托给 UuidIdentity#id_to_uuid
  # Backward-compatible class method; delegates to UuidIdentity#id_to_uuid
  def self.format_admin_id_as_uuid(admin_user_id)
    id_to_uuid(admin_user_id)
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
