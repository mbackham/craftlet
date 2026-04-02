class EtlLineageEdge < ApplicationRecord
  EDGE_TYPES = %w[etl derive aggregate].freeze

  belongs_to :upstream, class_name: 'EtlLineageNode'
  belongs_to :downstream, class_name: 'EtlLineageNode'

  validates :edge_type, inclusion: { in: EDGE_TYPES }
  validates :upstream_id, uniqueness: { scope: :downstream_id }

  def self.ransackable_attributes(auth_object = nil)
    %w[edge_type transform_logic created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[upstream downstream]
  end
end
