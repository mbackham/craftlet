class DwFactPayment < ApplicationRecord
  scope :successful, -> { where(status: 'paid') }
  scope :in_batch, ->(batch_id) { where(etl_batch_id: batch_id) }

  def self.ransackable_attributes(auth_object = nil)
    %w[source_id order_source_id channel amount status paid_at synced_at etl_batch_id created_at]
  end
end
