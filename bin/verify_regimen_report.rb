#!/usr/bin/env ruby
# frozen_string_literal: true

# bin/verify_regimen_report.rb
#
# Snapshot and compare ArtService::Reports::RegimenDispensationData output to verify
# code changes (e.g. optimizing create_temp_patient_outcome) don't alter the report data.
#
# Usage:
#   # 1. Before making changes, save a baseline snapshot:
#   bundle exec rails runner bin/verify_regimen_report.rb snapshot --start_date=2026-01-01 --end_date=2026-01-31
#
#   # 2. After making changes, regenerate and compare:
#   bundle exec rails runner bin/verify_regimen_report.rb compare --start_date=2026-01-01 --end_date=2026-01-31
#
#   # 3. Regenerate without snapshotting (just runs the report, prints timing):
#   bundle exec rails runner bin/verify_regimen_report.rb regenerate --start_date=2026-01-01 --end_date=2026-01-31
#
# Options:
#   --start_date=DATE       required, e.g. 2026-01-01
#   --end_date=DATE         required, e.g. 2026-01-31
#   --type=TYPE             'pepfar' or blank for moh (default: blank)
#   --occupation=OCC        optional occupation filter
#   --dsd=DSD               optional dsd filter
#   --snapshot-dir=PATH     directory to save snapshots (default: tmp/regimen_report_snapshots)

require 'json'
require 'fileutils'
require 'optparse'

mode = ARGV.shift&.downcase
if mode.nil? || !%w[snapshot compare regenerate].include?(mode)
  warn 'Usage: bundle exec rails runner bin/verify_regimen_report.rb <snapshot|compare|regenerate> --start_date=YYYY-MM-DD --end_date=YYYY-MM-DD [options]'
  exit 1
end

options = { type: '', occupation: nil, dsd: nil, snapshot_dir: 'tmp/regimen_report_snapshots' }
OptionParser.new do |opts|
  opts.on('--start_date=DATE')   { |v| options[:start_date] = v }
  opts.on('--end_date=DATE')     { |v| options[:end_date] = v }
  opts.on('--type=TYPE')         { |v| options[:type] = v }
  opts.on('--occupation=OCC')    { |v| options[:occupation] = v }
  opts.on('--dsd=DSD')           { |v| options[:dsd] = v }
  opts.on('--snapshot-dir=DIR')  { |v| options[:snapshot_dir] = v }
end.parse!(ARGV)

if options[:start_date].nil? || options[:end_date].nil?
  warn 'Error: --start_date and --end_date are required'
  exit 1
end

FileUtils.mkdir_p(options[:snapshot_dir])

def snapshot_file(dir, start_date, end_date, type, occupation)
  slug = "#{start_date}_#{end_date}_#{type.presence || 'moh'}"
  slug += "_#{occupation.downcase}" if occupation.present?
  File.join(dir, "regimen_report_#{slug}.json")
end

def run_report(start_date, end_date, type, occupation, dsd)
  t0 = Time.now
  data = ArtService::Reports::RegimenSwitch.new(start_date: start_date.to_date, end_date: end_date.to_date,
                                                occupation:, dsd:).regimen_report(type)
  elapsed = (Time.now - t0).round(1)
  puts "Regenerated regimen report for #{start_date} – #{end_date} (type=#{type.presence || 'moh'}) in #{elapsed}s (#{data.size} patients)"
  data
end

# Normalize keys/values to plain JSON-safe structures with deterministic ordering
def normalize(data)
  data.map { |patient_id, attrs| [patient_id.to_s, attrs] }
      .sort_by { |patient_id, _| patient_id.to_i }
      .to_h
      .transform_values do |attrs|
        attrs.each_with_object({}) { |(k, v), h| h[k.to_s] = v }
             .tap { |h| h['medication'] = Array(h['medication']).map { |m| m.transform_keys(&:to_s) } }
      end
end

def diff_reports(baseline, current)
  added   = current.keys - baseline.keys
  removed = baseline.keys - current.keys
  changed = (baseline.keys & current.keys).select { |k| baseline[k] != current[k] }

  { added:, removed:,
    changed: changed.map { |k| { patient_id: k, before: baseline[k], after: current[k] } } }
end

start_date  = options[:start_date]
end_date    = options[:end_date]
type        = options[:type]
occupation  = options[:occupation]
dsd         = options[:dsd]
snap_path   = snapshot_file(options[:snapshot_dir], start_date, end_date, type, occupation)

case mode
when 'snapshot'
  data = normalize(run_report(start_date, end_date, type, occupation, dsd))
  File.write(snap_path, JSON.pretty_generate(data))
  puts "Snapshot saved to #{snap_path} (#{data.size} patients)"

when 'regenerate'
  run_report(start_date, end_date, type, occupation, dsd)
  puts "Run 'snapshot' to save a baseline, or 'compare' to diff against a saved baseline."

when 'compare'
  unless File.exist?(snap_path)
    warn "No baseline snapshot found at #{snap_path}."
    warn "Run 'snapshot' first to capture a baseline before making changes."
    exit 1
  end

  baseline = JSON.parse(File.read(snap_path))
  puts "Baseline: #{snap_path} (#{baseline.size} patients)"

  current = normalize(run_report(start_date, end_date, type, occupation, dsd))
  diff = diff_reports(baseline, current)

  if diff[:added].empty? && diff[:removed].empty? && diff[:changed].empty?
    puts "\n\u2713 PASS \u2014 All #{baseline.size} patients match the baseline exactly."
    exit 0
  else
    puts "\n\u2717 FAIL \u2014 Report data differs from baseline:"

    unless diff[:added].empty?
      puts "\n  NEW patients (#{diff[:added].size}): #{diff[:added].first(20).join(', ')}"
    end

    unless diff[:removed].empty?
      puts "\n  REMOVED patients (#{diff[:removed].size}): #{diff[:removed].first(20).join(', ')}"
    end

    unless diff[:changed].empty?
      puts "\n  CHANGED patients (#{diff[:changed].size}):"
      diff[:changed].first(20).each do |c|
        puts "    patient_id=#{c[:patient_id]}"
        puts "      before: #{c[:before].to_json}"
        puts "      after : #{c[:after].to_json}"
      end
      puts "  ... (#{diff[:changed].size - 20} more)" if diff[:changed].size > 20
    end

    exit 1
  end
end
