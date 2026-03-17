# frozen_string_literal: true

class RenameFrozenToFundsFrozenInSettlements < ActiveRecord::Migration[7.0]
  def up
    execute "UPDATE settlements SET status = 'funds_frozen' WHERE status = 'frozen'"
  end

  def down
    execute "UPDATE settlements SET status = 'frozen' WHERE status = 'funds_frozen'"
  end
end
