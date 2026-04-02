class DwFactSettlement < ApplicationRecord
  scope :completed, -> { where(status: 'confirmed') }
  scope :in_batch, ->(batch_id) { where(etl_batch_id: batch_id) }

  def self.ransackable_attributes(auth_object = nil)
    %w[source_id merchant_source_id net_amount status period_start period_end synced_at etl_batch_id created_at]
  end
end
