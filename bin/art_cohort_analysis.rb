#!/usr/bin/env rails runner
# ART Cohort Report Analysis - Using Frontend Cohort Calculation Logic
# This script uses ArtService::Reports::CohortBuilder for proper outcome calculation
# matching the frontend reporting system

require 'art_service/reports/cohort_builder'
require 'art_service/reports/cohort_struct'

# Suppress verbose ActiveRecord debug logging
ActiveRecord::Base.logger = Logger.new(IO::NULL) if defined?(ActiveRecord)

puts "="*70
puts "ART COHORT REPORT ANALYSIS - FRONTEND CALCULATED OUTCOMES"
puts "="*70

begin
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
    puts "\n" + "-"*70
    puts "Fetching: #{quarter_name} (#{dates[:start]} to #{dates[:end]})"
    puts "-"*70
    
    begin
      # Build cohort using the proper frontend calculation engine
      cohort_struct = ArtService::Reports::CohortStruct.new
      cohort = builder.build(
        cohort_struct,
        dates[:start],
        dates[:end],
        nil  # occupation filter (nil = all occupations)
      )
      
      # Extract key indicators
      cum_total_registered = cohort.cum_total_registered || 0
      total_alive_on_art = cohort.total_alive_and_on_art.length rescue 0
      defaulted = cohort.defaulted.length rescue 0
      died = cohort.died_total.length rescue 0
      transferred_out = cohort.transfered_out.length rescue 0
      
      results[quarter_name] = {
        period: "#{dates[:start]} to #{dates[:end]}",
        cum_total_registered: cum_total_registered,
        total_alive_on_art: total_alive_on_art,
        defaulted: defaulted,
        died: died,
        transferred_out: transferred_out
      }
      
      # Calculate metrics
      retention = cum_total_registered > 0 ? (total_alive_on_art.to_f / cum_total_registered * 100).round(2) : 0
      default_rate = total_alive_on_art > 0 ? (defaulted.to_f / total_alive_on_art * 100).round(2) : 0
      
      puts "  Cumulative Ever Registered:       #{cum_total_registered.to_s.rjust(8)} patients"
      puts "  Total Alive & On ART:             #{total_alive_on_art.to_s.rjust(8)} patients"
      puts "  Defaulted:                        #{defaulted.to_s.rjust(8)} patients"
      puts "  Died:                             #{died.to_s.rjust(8)} patients"
      puts "  Transferred Out:                  #{transferred_out.to_s.rjust(8)} patients"
      puts ""
      puts "  ► Retention Rate:                  #{retention.to_s.rjust(7)}% (target: ≥90%)"
      puts "  ► Default Rate:                    #{default_rate.to_s.rjust(7)}% (target: <3%)"
      
    rescue => e
      puts "  ERROR: #{e.message}"
      results[quarter_name] = nil
    end
  end
  
  
  puts "\n" + "="*70
  puts "SUMMARY AND TRENDS"
  puts "="*70
  
  valid_results = results.compact
  
  if valid_results.size > 0
    puts "\nBASELINE (Q1 2025):"
    if results['Q1 2025']
      q1 = results['Q1 2025']
      puts "  • Cumulative Registered:     #{q1[:cum_total_registered].to_s.ljust(8)} patients"
      puts "  • Alive & On ART:            #{q1[:total_alive_on_art].to_s.ljust(8)} patients"  
      puts "  • Defaulted:                 #{q1[:defaulted].to_s.ljust(8)} patients"
      puts "  • Died:                      #{q1[:died].to_s.ljust(8)} patients"
      puts "  • Transferred Out:           #{q1[:transferred_out].to_s.ljust(8)} patients"
    end
    
    puts "\nQUARTER-ON-QUARTER OUTCOME CHANGES:"
    quarters.keys.each_cons(2) do |prev_q, curr_q|
      if results[prev_q] && results[curr_q]
        prev = results[prev_q]
        curr = results[curr_q]
        
        reg_change = curr[:cum_total_registered] - prev[:cum_total_registered]
        art_change = curr[:total_alive_on_art] - prev[:total_alive_on_art]
        def_change = curr[:defaulted] - prev[:defaulted]
        died_change = curr[:died] - prev[:died]
        to_change = curr[:transferred_out] - prev[:transferred_out]
        
        puts "\n  #{prev_q} → #{curr_q}:"
        puts "    Cumulative Registered:    #{(reg_change >= 0 ? '+' : '')}#{reg_change.to_s.rjust(6)} patients"
        puts "    Alive & On ART:          #{(art_change >= 0 ? '+' : '')}#{art_change.to_s.rjust(6)} patients"
        puts "    Defaulted:               #{(def_change >= 0 ? '+' : '')}#{def_change.to_s.rjust(6)} patients"
        puts "    Died:                    #{(died_change >= 0 ? '+' : '')}#{died_change.to_s.rjust(6)} patients"
        puts "    Transferred Out:         #{(to_change >= 0 ? '+' : '')}#{to_change.to_s.rjust(6)} patients"
      end
    end
  end
  
  puts "\n" + "="*70
  puts "OUTCOME BREAKDOWN - Q2 2026 (Latest)"
  puts "="*70
  
  if results['Q2 2026']
    latest = results['Q2 2026']
    total_outcomes = latest[:total_alive_on_art] + latest[:defaulted] + latest[:died] + latest[:transferred_out]
    cum_reg = latest[:cum_total_registered]
    
    if cum_reg > 0
      puts "\n  From #{cum_reg} cumulative ever registered:"
      puts "    On ART:                #{latest[:total_alive_on_art].to_s.rjust(4)} patients (#{(latest[:total_alive_on_art].to_f / cum_reg * 100).round(1)}%)"
      puts "    Defaulted:             #{latest[:defaulted].to_s.rjust(4)} patients (#{(latest[:defaulted].to_f / cum_reg * 100).round(1)}%)"
      puts "    Died:                  #{latest[:died].to_s.rjust(4)} patients (#{(latest[:died].to_f / cum_reg * 100).round(1)}%)"
      puts "    Transferred Out:       #{latest[:transferred_out].to_s.rjust(4)} patients (#{(latest[:transferred_out].to_f / cum_reg * 100).round(1)}%)"
      unaccounted = cum_reg - total_outcomes
      puts "    Unaccounted For:       #{unaccounted.to_s.rjust(4)} patients (#{(unaccounted.to_f / cum_reg * 100).round(1)}%)"
    end
  end
  
  puts "\n" + "="*70
  puts "PERFORMANCE BENCHMARKS"
  puts "="*70
  puts "\n  Target Retention Rate:        ≥90% (well-functioning program)"
  puts "  Target Default Rate:          <3%  (excellent), <5% (acceptable)"
  puts "  Target On Treatment:          ≥90% of cumulative ever registered"
  puts "\n  NOTE: Data calculated using frontend CohortBuilder with proper"
  puts "        outcome determination (death → stop → no orders → defaulted)"
  puts "\n" + "="*70
  
rescue Exception => e
  puts "\nFATAL ERROR: #{e.message}"
  puts "\nBacktrace:"
  puts e.backtrace.first(10).join("\n")
end
