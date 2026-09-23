#!/usr/bin/env rails runner
# ART Cohort Report Analysis - Using Frontend Cohort Calculation Logic
# This script uses ArtService::Reports::CohortBuilder for proper outcome calculation
# matching the frontend reporting system

require 'art_service/reports/cohort_builder'
require 'art_service/reports/cohort_struct'

# Suppress all logging
ActiveRecord::Base.logger = Logger.new(IO::NULL) if defined?(ActiveRecord)
Rails.logger = Logger.new(IO::NULL) if defined?(Rails)

output_file = "/tmp/art_cohort_analysis_output.txt"
File.open(output_file, 'w') do |f|
  f.puts "="*70
  f.puts "ART COHORT REPORT ANALYSIS - FRONTEND CALCULATED OUTCOMES"
  f.puts "="*70

  quarters = {
    'Q1 2025' => { start: Date.new(2025, 1, 1), end: Date.new(2025, 3, 31) },
    'Q2 2025' => { start: Date.new(2025, 4, 1), end: Date.new(2025, 6, 30) },
    'Q3 2025' => { start: Date.new(2025, 7, 1), end: Date.new(2025, 9, 30) },
    'Q4 2025' => { start: Date.new(2025, 10, 1), end: Date.new(2025, 12, 31) },
    'Q1 2026' => { start: Date.new(2026, 1, 1), end: Date.new(2026, 3, 31) },
    'Q2 2026' => { start: Date.new(2026, 4, 1), end: Date.new(2026, 6, 30) },
    'Q3 2026' => { start: Date.new(2026, 7, 1), end: Date.new(2026, 9, 30) },
    'Q4 2026' => { start: Date.new(2026, 10, 1), end: Date.new(2026, 12, 31) }
  }
  
  results = {}
  builder = ArtService::Reports::CohortBuilder.new(outcomes_definition: 'moh')
  
  quarters.each do |quarter_name, dates|
    f.puts "\n" + "-"*70
    f.puts "Period: #{quarter_name} (#{dates[:start]} to #{dates[:end]})"
    f.puts "-"*70
    
    begin
      # Build cohort using the proper frontend calculation engine
      cohort_struct = ArtService::Reports::CohortStruct.new
      cohort = builder.build(
        cohort_struct,
        dates[:start],
        dates[:end],
        nil  # occupation filter (nil = all occupations)
      )
      
      # Extract key indicators (convert to array if needed)
      cum_total_registered = cohort.cum_total_registered || 0
      total_alive_on_art = (cohort.total_alive_and_on_art.is_a?(Array) ? cohort.total_alive_and_on_art : cohort.total_alive_and_on_art.to_a).length rescue 0
      defaulted = (cohort.defaulted.is_a?(Array) ? cohort.defaulted : cohort.defaulted.to_a).length rescue 0
      died = (cohort.died_total.is_a?(Array) ? cohort.died_total : cohort.died_total.to_a).length rescue 0
      transferred_out = (cohort.transfered_out.is_a?(Array) ? cohort.transfered_out : cohort.transfered_out.to_a).length rescue 0
      
      results[quarter_name] = {
        cum_total_registered: cum_total_registered,
        total_alive_on_art: total_alive_on_art,
        defaulted: defaulted,
        died: died,
        transferred_out: transferred_out
      }
      
      # Calculate metrics
      retention = cum_total_registered > 0 ? (total_alive_on_art.to_f / cum_total_registered * 100).round(2) : 0
      default_rate = total_alive_on_art > 0 ? (defaulted.to_f / total_alive_on_art * 100).round(2) : 0
      
      f.puts "  Cumulative Ever Registered:       #{cum_total_registered.to_s.rjust(8)} patients"
      f.puts "  Total Alive & On ART:             #{total_alive_on_art.to_s.rjust(8)} patients"
      f.puts "  Defaulted:                        #{defaulted.to_s.rjust(8)} patients"
      f.puts "  Died:                             #{died.to_s.rjust(8)} patients"
      f.puts "  Transferred Out:                  #{transferred_out.to_s.rjust(8)} patients"
      f.puts ""
      f.puts "  ► Retention Rate:                  #{retention.to_s.rjust(7)}% (target: ≥90%)"
      f.puts "  ► Default Rate:                    #{default_rate.to_s.rjust(7)}% (target: <3%)"
      
    rescue => e
      f.puts "  ERROR: #{e.message}"
      results[quarter_name] = nil
    end
  end
  
  # Summary comparison
  f.puts "\n" + "="*70
  f.puts "TREND ANALYSIS: 2025 vs 2026"
  f.puts "="*70
  
  if results['Q1 2025'] && results['Q4 2026']
    q1_2025 = results['Q1 2025']
    q4_2026 = results['Q4 2026']
    
    reg_change = q4_2026[:cum_total_registered] - q1_2025[:cum_total_registered]
    reg_pct = q1_2025[:cum_total_registered] > 0 ? (reg_change.to_f / q1_2025[:cum_total_registered] * 100).round(2) : 0
    
    on_art_change = q4_2026[:total_alive_on_art] - q1_2025[:total_alive_on_art]
    on_art_pct = q1_2025[:total_alive_on_art] > 0 ? (on_art_change.to_f / q1_2025[:total_alive_on_art] * 100).round(2) : 0
    
    default_change = q4_2026[:defaulted] - q1_2025[:defaulted]
    
    f.puts "\nQ1 2025 Baseline → Q4 2026 Current:"
    f.puts "  Cumulative Registered:   #{q1_2025[:cum_total_registered]} → #{q4_2026[:cum_total_registered]}  (#{reg_pct > 0 ? '+' : ''}#{reg_pct}% change, #{reg_change > 0 ? '+' : ''}#{reg_change} patients)"
    f.puts "  On ART:                  #{q1_2025[:total_alive_on_art]} → #{q4_2026[:total_alive_on_art]}  (#{on_art_pct > 0 ? '+' : ''}#{on_art_pct}% change, #{on_art_change > 0 ? '+' : ''}#{on_art_change} patients)"
    f.puts "  Defaulted:               #{q1_2025[:defaulted]} → #{q4_2026[:defaulted]}  (change: #{default_change > 0 ? '+' : ''}#{default_change} patients)"
  end
  
  f.puts "\n" + "="*70
end

# Output results to console as well
File.readlines(output_file).each { |line| puts line }
