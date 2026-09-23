# frozen_string_literal: true

# Adds a patient_id-first covering index on orders to optimize the ART cohort
# outcomes computation.
#
# Context:
#   load_max_drug_orders (in Cohort::Outcomes#denormalize) is the inner-most hot
#   loop of update_cummulative_outcomes.  The existing index
#   idx_orders_type_voided_start_patient starts with order_type_id, forcing MySQL
#   to do a 1.8 M-row range scan followed by a GROUP BY temp table (32 s per
#   pass).
#
#   With (patient_id, order_type_id, voided, start_date) as the leading key,
#   MySQL can:
#     - Drive the join from temp_earliest_start_date (36 K patients, PK lookup)
#     - For each patient do a tight composite-key range scan:
#         patient_id = X AND order_type_id = 1 AND voided = 0
#         AND start_date < <end_date>
#     - Resolve GROUP BY patient_id directly from the index prefix — no temp
#       table, no filesort.
#
#   The same index covers load_patient_current_medication once the DATE()
#   function wrap on start_date is replaced with an explicit range predicate
#   (done in cohort_builder / outcomes changes shipped alongside this migration).
#
class AddIdxOrdersPatientTypeVoidedStart < ActiveRecord::Migration[6.1]
  INDEX_NAME = 'idx_orders_patient_type_voided_start'
  COLUMNS    = %i[patient_id order_type_id voided start_date].freeze

  def up
    unless index_exists?(:orders, COLUMNS, name: INDEX_NAME)
      add_index :orders, COLUMNS, name: INDEX_NAME
    end
  end

  def down
    if index_exists?(:orders, COLUMNS, name: INDEX_NAME)
      remove_index :orders, name: INDEX_NAME
    end
  end
end
