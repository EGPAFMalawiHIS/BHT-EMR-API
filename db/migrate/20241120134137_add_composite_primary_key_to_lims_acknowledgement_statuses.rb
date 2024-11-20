class AddCompositePrimaryKeyToLimsAcknowledgementStatuses < ActiveRecord::Migration[7.0]
  def change
    remove_foreign_key :lims_acknowledgement_statuses, column: :order_id
    execute <<-SQL
      ALTER TABLE lims_acknowledgement_statuses
      MODIFY COLUMN order_id INT NOT NULL,
      DROP PRIMARY KEY,
      ADD PRIMARY KEY (order_id, test);
    SQL
    add_foreign_key :lims_acknowledgement_statuses, :orders, column: :order_id, primary_key: :order_id
  end
end
