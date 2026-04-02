class DwFactOrder < ApplicationRecord
  belongs_to :dim_time, class_name: 'DwDimTime', foreign_key: :dim_time_id, optional: true

  scope :completed, -> { where(status: 'completed') }
  scope :paid, -> { where(status: 'paid') }
  scope :in_batch, ->(batch_id) { where(etl_batch_id: batch_id) }

  def self.ransackable_attributes(auth_object = nil)
    %w[source_id order_no customer_id merchant_id status total_amount paid_at synced_at etl_batch_id created_at]
  end
end
