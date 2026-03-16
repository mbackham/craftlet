class BankStatement < ApplicationRecord
  has_one_attached :file

  validates :channel, presence: true
  validates :statement_date, presence: true
  validates :status, presence: true

  enum status: { pending: 'pending', processing: 'processing', processed: 'processed', failed: 'failed' }

  def self.ransackable_attributes(auth_object = nil)
    ["channel", "created_at", "id", "status", "statement_date", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["file_attachment", "file_blob"]
  end
end
