#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'config/environment'

puts "========================================="
puts "Testing Optimized INSERT INTO temp_cohort_members"
puts "========================================="
puts ""

# Test parameters
end_date = Date.parse('2025-12-31')

puts "End Date: #{end_date}"
puts ""

# Initialize the service
service = ArtService::Reports::CohortBuilder.new(outcomes_definition: 'moh')

begin
  # Prepare tables (fast operation)
  puts "1. Preparing temporary tables..."
  service.send(:prepare_tables)
  
  # Load prerequisite temp tables (these are the optimizations)
  puts "2. Loading temp_other_patient_types..."
  t1 = Time.now
  service.send(:load_temp_other_patient_types, end_date)
  puts "   Time: #{(Time.now - t1).round(2)}s"
  
  puts "3. Loading temp_register_start_date..."
  t2 = Time.now
  service.send(:load_temp_register_start_date_table, end_date)
  puts "   Time: #{(Time.now - t2).round(2)}s"
  
  puts "4. Loading temp_order_details..."
  t3 = Time.now
  service.send(:load_temp_order_details, end_date)
  puts "   Time: #{(Time.now - t3).round(2)}s"
  
  puts "5. Loading temp_art_start_date..."
  t4 = Time.now
  service.send(:load_art_start_date, end_date)
  puts "   Time: #{(Time.now - t4).round(2)}s"
  
  puts "6. Loading temp_reason_for_starting_art (OPTIMIZED - replaces correlated subquery)..."
  t5 = Time.now
  service.send(:load_temp_reason_for_starting_art, end_date)
  puts "   Time: #{(Time.now - t5).round(2)}s"
  
  puts "7. Loading temp_art_start_date_by_enrollment (OPTIMIZED - replaces function call)..."
  t6 = Time.now
  service.send(:load_temp_art_start_date_by_enrollment, end_date)
  puts "   Time: #{(Time.now - t6).round(2)}s"
  
  puts ""
  puts "=" * 50
  puts "NOW TESTING MAIN QUERY: INSERT INTO temp_cohort_members"
  puts "=" * 50
  puts ""
  
  # Measure the main query that we optimized
  main_start = Time.now
  service.send(:load_data_into_temp_cohort_members_table, end_date)
  main_elapsed = Time.now - main_start
  
  puts "✓ Main query completed!"
  puts ""
  puts "Main Query Execution Time: #{main_elapsed.round(2)} seconds"
  puts ""
  
  # Get row counts
  puts "Results:"
  puts "-" * 40
  
  cohort_count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM temp_cohort_members")
  puts "Patients inserted into temp_cohort_members: #{cohort_count}"
  
  reason_count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM temp_reason_for_starting_art")
  puts "Pre-computed reasons (used in JOIN): #{reason_count}"
  
  art_enrollment_count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM temp_art_start_date_by_enrollment")
  puts "Pre-computed enrollment dates (used in JOIN): #{art_enrollment_count}"
  
  puts ""
  puts "=" * 50
  puts "SUMMARY"
  puts "=" * 50
  puts "The main INSERT INTO temp_cohort_members query now uses:"
  puts "  • JOIN to temp_reason_for_starting_art (instead of correlated subquery)"
  puts "  • JOIN to temp_art_start_date_by_enrollment (instead of function call)"
  puts ""
  puts "Total time for main query: #{main_elapsed.round(2)} seconds"
  puts ""
  
rescue StandardError => e
  puts "✗ Error occurred!"
  puts ""
  puts "Error: #{e.message}"
  puts ""
  puts "Backtrace:"
  puts e.backtrace.first(15).join("\n")
  exit 1
end
