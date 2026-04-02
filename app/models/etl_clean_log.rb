class EtlCleanLog < ApplicationRecord
  belongs_to :etl_clean_rule

  scope :in_batch, ->(batch_id) { where(batch_id: batch_id) }
  scope :for_table, ->(table) { where(source_table: table) }
  scope :for_field, ->(field) { where(field_name: field) }
  scope :recent, -> { order(created_at: :desc) }

  def self.ransackable_attributes(auth_object = nil)
    %w[batch_id source_table source_record_id field_name action_taken original_value cleaned_value etl_clean_rule_id created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[etl_clean_rule]
  end
end
