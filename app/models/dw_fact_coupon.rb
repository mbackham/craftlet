class DwFactCoupon < ApplicationRecord
  scope :used, -> { where.not(used_at: nil) }
  scope :in_batch, ->(batch_id) { where(etl_batch_id: batch_id) }

  def self.ransackable_attributes(auth_object = nil)
    %w[source_id user_id template_id discount_amount used_at synced_at etl_batch_id created_at]
  end
end
