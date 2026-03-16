class ReconciliationBatch < ApplicationRecord
  has_many :reconciliation_details, dependent: :destroy

  validates :target_date, presence: true
  validates :channel, presence: true
  
  enum status: { processing: 'processing', completed: 'completed', failed: 'failed' }

  def self.ransackable_attributes(auth_object = nil)
    ["channel", "created_at", "id", "matched_count", "mismatched_count", "status", "target_date", "total_count", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["reconciliation_details"]
  end
end
