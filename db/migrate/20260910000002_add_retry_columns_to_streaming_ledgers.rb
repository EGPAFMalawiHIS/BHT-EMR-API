# frozen_string_literal: true

class AddRetryColumnsToStreamingLedgers < ActiveRecord::Migration[8.0]
  def change
    add_column :streaming_ledgers, :next_attempt_at, :datetime
    add_column :streaming_ledgers, :locked_at, :datetime
    add_column :streaming_ledgers, :last_error_at, :datetime
    add_column :streaming_ledgers, :max_attempts, :integer, default: 20

    add_index :streaming_ledgers, [:status, :next_attempt_at]
  end
end
