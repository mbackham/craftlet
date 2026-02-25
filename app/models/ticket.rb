# frozen_string_literal: true

class Ticket < ApplicationRecord
  include AASM

  # === Constants ===
  CATEGORIES = %w[general payment order merchant other].freeze
  PRIORITIES = %w[low normal high urgent].freeze

  # === Associations ===
  has_many :messages, class_name: "TicketMessage", dependent: :destroy
  has_many :attachments, through: :messages, source: :attachments

  # === Validations ===
  validates :ticket_no, presence: true, uniqueness: true
  validates :subject,   presence: true
  validates :status,    presence: true
  validates :category,  inclusion: { in: CATEGORIES }
  validates :priority,  inclusion: { in: PRIORITIES }
  validates :creator_id, presence: true

  # === Callbacks ===
  before_validation :generate_ticket_no, on: :create

  # === AASM State Machine ===
  aasm column: "status" do
    state :open, initial: true
    state :assigned, :in_progress, :resolved, :closed

    event :assign do
      transitions from: [:open, :assigned], to: :assigned
    end

    event :start_work do
      transitions from: [:assigned], to: :in_progress
    end

    event :resolve do
      transitions from: [:open, :assigned, :in_progress], to: :resolved
    end

    event :close do
      transitions from: [:open, :assigned, :in_progress, :resolved], to: :closed
    end

    event :reopen do
      transitions from: [:resolved, :closed], to: :open
    end
  end

  # === Scopes ===
  scope :active,   -> { where(status: %w[open assigned in_progress]) }
  scope :resolved, -> { where(status: "resolved") }
  scope :closed,   -> { where(status: "closed") }
  scope :urgent,   -> { where(priority: "urgent") }
  scope :high,     -> { where(priority: %w[high urgent]) }

  # === Display Helpers ===
  def status_label
    I18n.t("ticket_statuses.#{status}", default: status.to_s.humanize)
  end

  def priority_label
    I18n.t("ticket_priorities.#{priority}", default: priority.to_s.humanize)
  end

  def category_label
    I18n.t("ticket_categories.#{category}", default: category.to_s.humanize)
  end

  # Creator lookup (UUID to User/AdminUser)
  def creator
    return nil if creator_id.blank?
    if creator_type == "AdminUser"
      id_num = creator_id.to_s.split('-').last.to_i
      AdminUser.find_by(id: id_num)
    else
      id_num = creator_id.to_s.split('-').last.to_i
      User.find_by(id: id_num)
    end
  end

  # Assignee lookup (UUID to AdminUser)
  def assignee
    return nil if assignee_id.blank?
    id_num = assignee_id.to_s.split('-').last.to_i
    AdminUser.find_by(id: id_num)
  end

  # Related order lookup
  def related_order
    return nil if order_id.blank?
    Order.find_by(id: order_id)
  end

  # === Ransack Configuration ===
  def self.ransackable_attributes(auth_object = nil)
    %w[id ticket_no subject status category priority creator_id assignee_id order_id created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[messages]
  end

  private

  def generate_ticket_no
    self.ticket_no ||= "TK-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
  end
end
