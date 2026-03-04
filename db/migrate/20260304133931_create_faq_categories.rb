class CreateFaqCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :faq_categories do |t|
      t.jsonb :name, default: {}, null: false
      t.string :slug
      t.integer :sort, default: 0
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :faq_categories, :slug, unique: true
  end
end
