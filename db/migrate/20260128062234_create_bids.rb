class CreateBids < ActiveRecord::Migration[7.1]
  def change
    create_table :bids do |t|
      t.references :order, null: false, foreign_key: true
      t.uuid :bidder_id, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :status, default: 'pending', null: false

      t.timestamps
    end

    add_index :bids, :bidder_id
    add_index :bids, :status
  end
end
