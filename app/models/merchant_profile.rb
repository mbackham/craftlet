# frozen_string_literal: true

class MerchantProfile < ApplicationRecord
  # === Constants ===
  STATUSES = %w[pending submitted approved rejected suspended].freeze
  
  # === Associations ===
  belongs_to :user
  has_many :review_logs, class_name: 'MerchantReviewLog', dependent: :destroy
  # Note: approved_by_admin_id and rejected_by_admin_id are UUID fields
  # AdminUser uses bigint IDs, so we can't use belongs_to directly
  # Use custom methods approved_by_admin and rejected_by_admin instead

  # === Validations ===
  validates :shop_name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  # === Callbacks ===
  before_validation :set_default_status, on: :create

  # === Scopes ===
  scope :pending, -> { where(status: 'pending') }
  scope :submitted, -> { where(status: 'submitted') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :suspended, -> { where(status: 'suspended') }
  scope :awaiting_review, -> { where(status: %w[pending submitted]) }

  # === Status Query Methods ===
  def pending?
    status == 'pending'
  end

  def submitted?
    status == 'submitted'
  end

  def approved?
    status == 'approved'
  end

  def rejected?
    status == 'rejected'
  end

  def suspended?
    status == 'suspended'
  end

  def can_approve?
    submitted?
  end

  def can_reject?
    submitted?
  end

  # === Masking Methods (敏感字段脱敏) ===
  
  # 银行账号脱敏：显示前4后4，中间用*代替
  def masked_bank_account_no
    return nil if bank_account_no_ciphertext.blank?
    # 假设解密后的银行账号长度 > 8
    # 由于目前未实现加密，暂时返回占位符
    '****' + '****' + '****'
  end

  # 身份证号脱敏：显示前3后4，中间用*代替
  # 格式：110***********1234
  def masked_idcard_no
    # 身份证号存储在哪个字段？目前 schema 中没有明确的身份证号字段
    # idcard_front_key 和 idcard_back_key 是 OSS 文件 key
    # 本期暂不处理，返回 nil
    nil
  end

  # === Display Helpers ===
  def status_label
    I18n.t("merchant_statuses.#{status}", default: status.humanize)
  end

  def full_address
    [address_province, address_city, address_district, address_detail].compact.join(' ')
  end

  # Custom admin lookup methods (UUID to bigint conversion)
  # Format: 00000000-0000-0000-0000-{12 digit ID}
  def approved_by_admin
    return nil if approved_by_admin_id.blank?
    
    numeric_id = approved_by_admin_id.to_s.split('-').last.to_i
    AdminUser.find_by(id: numeric_id)
  end

  def rejected_by_admin
    return nil if rejected_by_admin_id.blank?
    
    numeric_id = rejected_by_admin_id.to_s.split('-').last.to_i
    AdminUser.find_by(id: numeric_id)
  end

  # Helper to format admin user ID as UUID for storage
  def self.format_admin_id_as_uuid(admin_user_id)
    sprintf('00000000-0000-0000-0000-%012d', admin_user_id.to_i)
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id shop_name status address_province address_city created_at updated_at approved_at rejected_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[user review_logs]
  end

  private

  def set_default_status
    self.status ||= 'pending'
  end
end
