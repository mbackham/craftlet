class CreateElements < ActiveRecord::Migration[7.1]
  def change
    create_table :elements do |t|
      t.string :name, null: false
      t.string :category
      t.string :status, default: 'draft', null: false
      t.decimal :price, precision: 10, scale: 2
      t.string :oss_key
      t.string :thumbnail_key
      t.text :description
      t.datetime :shelved_at
      t.datetime :unshelved_at

      t.timestamps
    end

    add_index :elements, :status
    add_index :elements, :category
    add_index :elements, :created_at
  end
end
