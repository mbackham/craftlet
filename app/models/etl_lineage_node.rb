class EtlLineageNode < ApplicationRecord
  NODE_TYPES = %w[source_table fact_table dim_table metric report].freeze

  has_many :outgoing_edges, class_name: 'EtlLineageEdge', foreign_key: :upstream_id, dependent: :destroy
  has_many :incoming_edges, class_name: 'EtlLineageEdge', foreign_key: :downstream_id, dependent: :destroy
  has_many :downstream_nodes, through: :outgoing_edges, source: :downstream
  has_many :upstream_nodes, through: :incoming_edges, source: :upstream

  validates :node_type, presence: true, inclusion: { in: NODE_TYPES }
  validates :name, presence: true
  validates :name, uniqueness: { scope: :node_type }

  scope :active, -> { where(is_active: true) }
  scope :by_type, ->(type) { where(node_type: type) }

  def self.ransackable_attributes(auth_object = nil)
    %w[node_type name schema_name is_active created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[downstream_nodes upstream_nodes]
  end
end
