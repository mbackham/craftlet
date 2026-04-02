class CreateEtlLineageTables < ActiveRecord::Migration[7.1]
  def change
    create_table :etl_lineage_nodes do |t|
      t.string  :node_type, null: false
      t.string  :name, null: false
      t.string  :schema_name
      t.text    :description
      t.jsonb   :metadata, default: {}
      t.boolean :is_active, default: true
      t.timestamps
    end

    add_index :etl_lineage_nodes, [:node_type, :name], unique: true

    create_table :etl_lineage_edges do |t|
      t.references :upstream, null: false, foreign_key: { to_table: :etl_lineage_nodes }
      t.references :downstream, null: false, foreign_key: { to_table: :etl_lineage_nodes }
      t.string     :edge_type, default: 'etl'
      t.string     :transform_logic
      t.jsonb      :field_mapping, default: {}
      t.timestamps
    end

    add_index :etl_lineage_edges, [:upstream_id, :downstream_id], unique: true
  end
end
