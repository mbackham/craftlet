class CreateEtlCleanTables < ActiveRecord::Migration[7.1]
  def change
    create_table :etl_clean_rules do |t|
      t.string   :name, null: false
      t.string   :source_table, null: false
      t.string   :target_field, null: false
      t.string   :rule_type, null: false
      t.string   :action, default: 'skip'
      t.jsonb    :params, default: {}, null: false
      t.integer  :priority, default: 0
      t.boolean  :is_active, default: true
      t.text     :description
      t.timestamps
    end

    add_index :etl_clean_rules, :source_table
    add_index :etl_clean_rules, :rule_type
    add_index :etl_clean_rules, :is_active

    create_table :etl_clean_logs do |t|
      t.references :etl_clean_rule, null: false, foreign_key: true
      t.string     :batch_id, null: false
      t.string     :source_table, null: false
      t.bigint     :source_record_id, null: false
      t.string     :field_name, null: false
      t.text       :original_value
      t.text       :cleaned_value
      t.string     :action_taken
      t.timestamps
    end

    add_index :etl_clean_logs, :batch_id
    add_index :etl_clean_logs, :source_table
    add_index :etl_clean_logs, :source_record_id
  end
end
