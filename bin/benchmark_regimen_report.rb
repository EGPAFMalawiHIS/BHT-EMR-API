#!/usr/bin/env ruby
# frozen_string_literal: true

$stdout.sync = true
$stderr.sync = true

# bin/benchmark_regimen_report.rb
#
# Runs every step of ArtService::Reports::RegimenDispensationData individually and
# reports how long each one takes, from slowest to fastest. Useful for confirming
# where the regimen_report endpoint spends its time (e.g. create_temp_patient_outcome).
#
# Usage:
#   bundle exec rails runner bin/benchmark_regimen_report.rb --start_date=2026-01-01 --end_date=2026-01-31
#   bundle exec rails runner bin/benchmark_regimen_report.rb --start_date=2026-01-01 --end_date=2026-01-31 --type=pepfar

require 'benchmark'
require 'optparse'

options = { type: '', occupation: nil, dsd: nil }
OptionParser.new do |opts|
  opts.on('--start_date=DATE') { |v| options[:start_date] = v }
  opts.on('--end_date=DATE')   { |v| options[:end_date] = v }
  opts.on('--type=TYPE')       { |v| options[:type] = v }
  opts.on('--occupation=OCC')  { |v| options[:occupation] = v }
  opts.on('--dsd=DSD')         { |v| options[:dsd] = v }
end.parse!(ARGV)

if options[:start_date].nil? || options[:end_date].nil?
  warn 'Usage: bundle exec rails runner bin/benchmark_regimen_report.rb --start_date=YYYY-MM-DD --end_date=YYYY-MM-DD [--type=pepfar] [--occupation=OCC] [--dsd=DSD]'
  exit 1
end

start_date = options[:start_date].to_date
end_date   = options[:end_date].to_date

puts '=' * 70
puts 'Regimen Dispensation Report Benchmark'
puts "  Period     : #{start_date} \u2013 #{end_date}"
puts "  Type       : #{options[:type].presence || 'moh'}"
puts "  Occupation : #{options[:occupation] || 'All'}"
puts "  DSD        : #{options[:dsd] || 'All'}"
puts '=' * 70
puts

report = ArtService::Reports::RegimenDispensationData.new(start_date:, end_date:, type: options[:type],
                                                          occupation: options[:occupation], dsd: options[:dsd])

results = []

def timed(label, results)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  results << { label:, seconds: elapsed.round(3) }
  puts format('  %-45s %7.3fs', label, elapsed)
rescue StandardError => e
  puts format('  %-45s ERROR: %s', label, e.message)
  results << { label:, seconds: nil, error: e.message }
end

timed('drop_regimen_data', results)              { report.send(:drop_regimen_data) }
timed('create_temp_current_dispensation', results) { report.send(:create_temp_current_dispensation) }
timed('create_temp_drug_dispensed', results)      { report.send(:create_temp_drug_dispensed) }
timed('create_temp_current_regimen', results)     { report.send(:create_temp_current_regimen) }
timed('create_temp_current_patient_regimen', results) { report.send(:create_temp_current_patient_regimen) }
timed('create_temp_patient_outcome', results)     { report.send(:create_temp_patient_outcome) }
timed('create_temp_vl_result', results)           { report.send(:create_temp_vl_result) }
timed('create_temp_current_vl_results', results)  { report.send(:create_temp_current_vl_results) }
timed('create_temp_regimen_patient_weight', results) { report.send(:create_temp_regimen_patient_weight) }
timed('create_temp_patient_start_date', results)  { report.send(:create_temp_patient_start_date) }

clients = nil
timed('process_clients', results) { clients = report.send(:process_clients) }

puts
puts '=' * 70
puts "Total patients returned: #{clients&.size}"
puts '=' * 70
puts
puts 'Steps sorted slowest -> fastest:'
results.compact.sort_by { |r| -(r[:seconds] || 0) }.each do |r|
  puts format('  %-45s %7.3fs', r[:label], r[:seconds] || 0)
end

total = results.sum { |r| r[:seconds] || 0 }
puts
puts format('Total measured time: %.3fs', total)
