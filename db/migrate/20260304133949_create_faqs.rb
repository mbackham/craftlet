class CreateFaqs < ActiveRecord::Migration[7.1]
  def change
    create_table :faqs do |t|
      t.jsonb :question, default: {}, null: false
      t.jsonb :answer, default: {}, null: false
      t.bigint :faq_category_id
      t.integer :sort, default: 0
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :faqs, :faq_category_id
    add_foreign_key :faqs, :faq_categories
  end
end
