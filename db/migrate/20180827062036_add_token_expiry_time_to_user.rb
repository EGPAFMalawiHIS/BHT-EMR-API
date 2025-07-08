# frozen_string_literal: true

class AddTokenExpiryTimeToUser < ActiveRecord::Migration[5.2]
  def up
    execute 'ALTER TABLE users MODIFY COLUMN date_created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()'
    add_column :users, :token_expiry_time, :date
  end

  def down
    remove_column :users, :token_expiry_time if column_exists?(:users, :token_expiry_time)
  end
end
