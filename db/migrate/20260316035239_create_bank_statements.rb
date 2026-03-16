class CreateBankStatements < ActiveRecord::Migration[7.1]
  def change
    create_table :bank_statements do |t|
      t.string :channel
      t.date :statement_date
      t.string :status

      t.timestamps
    end
  end
end
