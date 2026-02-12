# frozen_string_literal: true

class Feedback < ApplicationRecord
  # =============================
  # 关联
  # =============================
  belongs_to :user, optional: true, polymorphic: true
  belongs_to :admin_user, optional: true
  
  # Active Storage - 截图附件
  has_many_attached :screenshots do |attachable|
    attachable.variant :thumb, resize_to_limit: [200, 200]
    attachable.variant :medium, resize_to_limit: [800, 600]
  end
  
  # =============================
  # 枚举
  # =============================
  enum :feedback_type, {
    bug_report: 'bug_report',
    feature_request: 'feature_request',
    complaint: 'complaint',
    other: 'other'
  }, prefix: true, validate: true
  
  enum :status, {
    pending: 'pending',
    reviewing: 'reviewing',
    resolved: 'resolved',
    closed: 'closed'
  }, prefix: true, validate: true
  
  enum :priority, {
    low: 'low',
    medium: 'medium',
    high: 'high',
    urgent: 'urgent'
  }, prefix: true, validate: true
  
  # =============================
  # 验证
  # =============================
  validates :feedback_type, presence: true
  validates :subject, presence: true, length: { maximum: 200 }
  validates :content, presence: true, length: { maximum: 5000 }
  validates :submitter_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :submitter_name, presence: true, if: -> { user_id.blank? }
  validates :tracking_number, presence: true, uniqueness: true
  
  # 图片附件验证
  validate :acceptable_screenshots
  
  # =============================
  # 回调
  # =============================
  before_validation :generate_tracking_number, on: :create
  before_validation :extract_user_info, if: -> { user.present? }
  after_create :send_confirmation_email
  
  # =============================
  # Scope
  # =============================
  scope :today, -> { where('created_at >= ?', Time.current.beginning_of_day) }
  scope :this_week, -> { where('created_at >= ?', 1.week.ago) }
  scope :unresolved, -> { where.not(status: 'resolved') }
  scope :by_priority, -> { order(Arel.sql(
    "CASE priority 
      WHEN 'urgent' THEN 1 
      WHEN 'high' THEN 2 
      WHEN 'medium' THEN 3 
      WHEN 'low' THEN 4 
    END"
  )) }
  scope :recent, -> { order(created_at: :desc) }
  
  # =============================
  # 实例方法
  # =============================
  
  # 生成追踪号
  def generate_tracking_number
    return if tracking_number.present?
    
    date_prefix = Time.current.strftime('%Y%m%d')
    sequence = Feedback.where('created_at >= ?', Time.current.beginning_of_day).count + 1
    self.tracking_number = "FB#{date_prefix}#{sequence.to_s.rjust(4, '0')}"
  end
  
  # 从关联用户提取信息
  def extract_user_info
    if user.is_a?(User)
      self.submitter_email ||= user.email
      self.submitter_name ||= user.email.split('@').first
      self.user_type = 'User'
    elsif user.is_a?(MerchantProfile)
      self.submitter_email ||= user.contact_email
      self.submitter_name ||= user.merchant_name
      self.user_type = 'MerchantProfile'
    end
  end
  
  # 发送确认邮件
  def send_confirmation_email
    FeedbackMailer.submission_confirmation(self).deliver_later
  end
  
  # 标记为已解决
  def mark_as_resolved!(admin_user)
    update!(
      status: 'resolved',
      resolved_at: Time.current,
      admin_user: admin_user
    )
  end
  
  # 检查是否可以关闭
  def can_close?
    status_resolved? && resolved_at.present? && resolved_at < 7.days.ago
  end
  
  # I18n 辅助方法
  def feedback_type_i18n
    I18n.t("activerecord.attributes.feedback.feedback_types.#{feedback_type}")
  end
  
  def status_i18n
    I18n.t("activerecord.attributes.feedback.statuses.#{status}")
  end
  
  def priority_i18n
    I18n.t("activerecord.attributes.feedback.priorities.#{priority}")
  end
  
  # =============================
  # Ransack 配置
  # =============================
  def self.ransackable_attributes(auth_object = nil)
    %w[tracking_number feedback_type status priority submitter_email
       user_id user_type admin_user_id created_at updated_at resolved_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[user admin_user]
  end

  private
  
  # 验证截图文件
  def acceptable_screenshots
    return unless screenshots.attached?
    
    if screenshots.count > 5
      errors.add(:screenshots, '最多上传 5 张图片')
    end
    
    screenshots.each do |screenshot|
      unless screenshot.content_type.in?(%w[image/jpeg image/png image/gif image/webp])
        errors.add(:screenshots, '只支持 JPG、PNG、GIF、WebP 格式的图片')
      end
      
      if screenshot.byte_size > 5.megabytes
        errors.add(:screenshots, '单个图片不能超过 5MB')
      end
    end
  end
end
