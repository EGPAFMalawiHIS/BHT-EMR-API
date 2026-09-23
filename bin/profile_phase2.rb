#!/usr/bin/env ruby
# frozen_string_literal: true

# bin/profile_phase2.rb
#
# Profiles every individual step inside update_cum_outcome (Phase 2).
# Runs each step sequentially with start: false only (representative sample).
#
# Usage:
#   DISABLE_SPRING=1 RAILS_ENV=development bundle exec rails runner bin/profile_phase2.rb "Q3 2024"

$stdout.sync = true

START_DATE = ARGV.find { |a| a =~ /\d{4}/ }
                 &.then { |n| n.match(/Q([1-4])\s+(\d{4})/) }
                 &.then { |m| Date.new(m[2].to_i, ((m[1].to_i - 1) * 3) + 1, 1) } || Date.new(2024, 7, 1)
END_DATE = START_DATE.next_month.next_month.next_month - 1

def timed(label)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  puts format('  %-60s %7.3fs', label, elapsed)
  elapsed
rescue StandardError => e
  puts format("  %-60s ERROR: #{e.message}", label)
  0
end

puts '=' * 78
puts "Phase 2 Step Profiler  |  #{START_DATE} – #{END_DATE}"
puts '=' * 78

# ── Build Phase 1 first so outcome tables have data ──────────────────────────
puts "\nBuilding Phase 1 (needed before Phase 2)..."
builder = ArtService::Reports::CohortBuilder.new
t_p1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
builder.send(:prepare_tables)
builder.send(:load_phase1_parallel, END_DATE)
builder.send(:load_data_into_temp_earliest_start_date, END_DATE.to_date, nil)
puts format('  Phase 1 done in %.1fs', Process.clock_gettime(Process::CLOCK_MONOTONIC) - t_p1)

# ── Now profile Phase 2 internals ────────────────────────────────────────────
puts "\nPhase 2 step-by-step (start: false — end-date outcomes pass)"
puts '-' * 78

outcomes = ArtService::Reports::Cohort::Outcomes.new(
  end_date: END_DATE,
  start_date: START_DATE,
  definition: 'moh',
  rebuild: 'true'
)

# Truncate outcome tables fresh
outcomes.send(:truncate_outcome_tables, start: false)

results = []

# --- denormalize steps ---
results << { label: 'load_max_drug_orders', s: timed('load_max_drug_orders (MAX ARV order per patient)') do
  outcomes.send(:load_max_drug_orders, start: false)
end }
results << { label: 'update_max_drug_orders', s: timed('update_max_drug_orders (windowed recent orders)') do
  outcomes.send(:update_max_drug_orders, start: false)
end }
results << { label: 'load_patient_current_medication', s: timed('load_patient_current_medication (pill qty per drug)') do
  outcomes.send(:load_patient_current_medication, start: false)
end }
results << { label: 'update_patient_current_medication', s: timed('update_patient_current_medication (expiry+defaulter dates)') do
  outcomes.send(:update_patient_current_medication, start: false)
end }
results << { label: 'load_min_auto_expire_date', s: timed('load_min_auto_expire_date (earliest expiry per patient)') do
  outcomes.send(:load_min_auto_expire_date, start: false)
end }
results << { label: 'load_max_patient_state', s: timed('load_max_patient_state (latest program state date)') do
  outcomes.send(:load_max_patient_state, start: false)
end }
results << { label: 'load_patient_current_state', s: timed('load_patient_current_state (state name lookup)') do
  outcomes.send(:load_patient_current_state, start: false)
end }
results << { label: 'update_patient_current_state', s: timed('update_patient_current_state (resolve ties)') do
  outcomes.send(:update_patient_current_state, start: false)
end }

# --- outcome assignment steps ---
results << { label: 'load_patients_who_died', s: timed('load_patients_who_died (step 1)') do
  outcomes.send(:load_patients_who_died, start: false)
end }
results << { label: 'load_other_patient_who_died', s: timed('load_other_patient_who_died (step 1b)') do
  outcomes.send(:load_other_patient_who_died, start: false)
end }
results << { label: 'load_patients_who_stopped_treatment', s: timed('load_patients_who_stopped_treatment (step 2)') do
  outcomes.send(:load_patients_who_stopped_treatment, start: false)
end }
results << { label: 'load_patients_without_drug_orders', s: timed('load_patients_without_drug_orders (step 3)') do
  outcomes.send(:load_patients_without_drug_orders, start: false)
end }
results << { label: 'load_patient_calculated_outcomes_optimized', s: timed('load_patient_calculated_outcomes_optimized (steps 4+5)') do
  outcomes.send(:load_patient_calculated_outcomes_optimized, start: false)
end }

total = results.sum { |r| r[:s] }

puts
puts '=' * 78
puts 'SUMMARY — slowest first'
puts '=' * 78
puts format('  %-60s %7s  %5s', 'Step', 'Seconds', 'Share')
puts '  ' + '-' * 75
results.sort_by { |r| -r[:s] }.each do |r|
  share = total > 0 ? (r[:s] / total * 100).round(1) : 0
  bar   = '#' * (share / 2).round
  puts format('  %-60s %7.3fs  %4.1f%% %s', r[:label], r[:s], share, bar)
end
puts '  ' + '-' * 75
puts format('  %-60s %7.3fs  100.0%%', 'TOTAL (start: false pass)', total)
puts
puts 'Note: actual update_cum_outcome runs TWO passes in parallel (start: false + start: true).'
puts 'Wall time ≈ max(pass_false, pass_true). Both passes have similar step profiles.'
