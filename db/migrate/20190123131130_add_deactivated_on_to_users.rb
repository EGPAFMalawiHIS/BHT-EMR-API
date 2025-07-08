# frozen_string_literal: true

class AddDeactivatedOnToUsers < ActiveRecord::Migration[5.2]
  def up
    add_column :users, :deactivated_on, :datetime, default: nil unless column_exists?(:users, :deactivated_on)
  end

  def down
    remove_column :users, :deactivated_on if column_exists?(:users, :deactivated_on)
  end
end
