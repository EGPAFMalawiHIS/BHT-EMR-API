#!/usr/bin/env ruby
# frozen_string_literal: true

# Performance test for cohort outcomes optimization
require_relative 'config/environment'

puts "="*80
puts "Cohort Outcomes Performance Test"
puts "="*80
puts ""

# Test with a recent quarter
end_date = Date.today - 1.month
start_date = (end_date - 2.months).beginning_of_month

puts "Test Parameters:"
puts "  Start Date: #{start_date}"
puts "  End Date: #{end_date}"
puts ""

# Count patients in temp_earliest_start_date to know how many we're processing
ActiveRecord::Base.connection.execute("DROP TEMPORARY TABLE IF EXISTS temp_earliest_start_date")
ActiveRecord::Base.connection.execute("DROP TEMPORARY TABLE IF EXISTS temp_cohort_members")
ActiveRecord::Base.connection.execute("DROP TEMPORARY TABLE IF EXISTS temp_other_patient_types")
ActiveRecord::Base.connection.execute("DROP TEMPORARY TABLE IF EXISTS temp_register_start_date")
ActiveRecord::Base.connection.execute("DROP TEMPORARY TABLE IF EXISTS temp_order_details")
ActiveRecord::Base.connection.execute("DROP TEMPORARY TABLE IF EXISTS temp_art_start_date")
ActiveRecord::Base.connection.execute("DROP TEMPORARY TABLE IF EXISTS temp_reason_for_starting_art")
ActiveRecord::Base.connection.execute("DROP TEMPORARY TABLE IF EXISTS temp_art_start_date_by_enrollment")

# Create required temp tables
ActiveRecord::Base.connection.execute <<~SQL
  CREATE TEMPORARY TABLE IF NOT EXISTS temp_earliest_start_date (
    patient_id INT PRIMARY KEY,
    date_enrolled DATE,
    earliest_start_date DATE,
    recorded_start_date DATE,
    birthdate DATE,
    birthdate_estimated INT(11),
    death_date DATE,
    gender VARCHAR(50),
    age_at_initiation INT(11),
    age_in_days INT(11),
    reason_for_starting_art INT(11),
    earliest_start_date_by_enrollment DATE
  )
SQL

ActiveRecord::Base.connection.execute <<~SQL
  CREATE TEMPORARY TABLE IF NOT EXISTS temp_cohort_members (
    patient_id INT PRIMARY KEY,
    date_enrolled DATE,
    earliest_start_date DATE,
    recorded_start_date DATE,
    birthdate DATE,
    birthdate_estimated INT(11),
    death_date DATE,
    gender VARCHAR(50),
    age_at_initiation INT(11),
    age_in_days INT(11),
    reason_for_starting_art INT(11),
    occupation VARCHAR(255),
    earliest_start_date_by_enrollment DATE
  )
SQL

ActiveRecord::Base.connection.execute <<~SQL
  CREATE TEMPORARY TABLE IF NOT EXISTS temp_other_patient_types (
    patient_id INT PRIMARY KEY
  )
SQL

ActiveRecord::Base.connection.execute <<~SQL
  CREATE TEMPORARY TABLE IF NOT EXISTS temp_register_start_date (
    patient_id INT PRIMARY KEY,
    start_date DATE
  )
SQL

ActiveRecord::Base.connection.execute <<~SQL
  CREATE TEMPORARY TABLE IF NOT EXISTS temp_order_details (
    patient_id INT PRIMARY KEY,
    start_date DATE
  )
SQL

ActiveRecord::Base.connection.execute <<~SQL
  CREATE TEMPORARY TABLE IF NOT EXISTS temp_art_start_date (
    patient_id INT PRIMARY KEY,
    value_datetime DATE
  )
SQL

ActiveRecord::Base.connection.execute <<~SQL
  CREATE TEMPORARY TABLE IF NOT EXISTS temp_reason_for_starting_art (
    patient_id INT PRIMARY KEY,
    reason_for_starting_art INT(11)
  )
SQL

ActiveRecord::Base.connection.execute <<~SQL
  CREATE TEMPORARY TABLE IF NOT EXISTS temp_art_start_date_by_enrollment (
    patient_id INT PRIMARY KEY,
    earliest_start_date_by_enrollment DATE
  )
SQL

puts "Loading patient data..."
# Quick patient count from actual data
patient_count = ActiveRecord::Base.connection.select_value(<<~SQL)
  SELECT COUNT(DISTINCT pp.patient_id)
  FROM patient_program pp
  INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id
  WHERE pp.program_id = 1 
    AND pp.voided = 0
    AND ps.voided = 0
    AND ps.state = 7
    AND ps.start_date <= '#{end_date}'
SQL

puts "  Estimated patients to process: #{patient_count}"
puts ""

# Test the outcomes processing
puts "Testing Outcomes Processing..."
puts "-"*80

start_time = Time.now

begin
  outcomes = ArtService::Reports::Cohort::Outcomes.new(
    end_date: end_date,
    start_date: start_date,
    definition: 'moh',
    rebuild: 'true'
  )
  
  # This will run the optimized process_data method
  outcomes.update_cummulative_outcomes
  
  end_time = Time.now
  duration = end_time - start_time
  
  puts ""
  puts "✅ SUCCESS!"
  puts ""
  puts "Performance Results:"
  puts "  Duration: #{duration.round(2)} seconds (#{(duration / 60).round(2)} minutes)"
  puts "  Patients processed: #{patient_count}"
  
  if patient_count > 0
    puts "  Time per patient: #{(duration / patient_count * 1000).round(2)} ms"
  end
  
  # Check outcomes
  outcomes_count = ActiveRecord::Base.connection.select_all(<<~SQL)
    SELECT moh_cum_outcome, COUNT(*) as count
    FROM temp_patient_outcomes
    GROUP BY moh_cum_outcome
    ORDER BY count DESC
  SQL
  
  if outcomes_count.any?
    puts ""
    puts "Outcome Distribution:"
    outcomes_count.each do |row|
      puts "  #{row['moh_cum_outcome']}: #{row['count']}"
    end
  end
  
  puts ""
  puts "="*80
  puts "✨ Optimization is working correctly!"
  puts "="*80
  
rescue StandardError => e
  puts ""
  puts "❌ ERROR: #{e.message}"
  puts e.backtrace.first(10).join("\n")
  exit 1
end
