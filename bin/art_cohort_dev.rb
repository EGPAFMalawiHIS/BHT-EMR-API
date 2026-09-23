#!/usr/bin/env rails runner
# ART Cohort Report Analysis - Development Mode
require 'art_service/reports/cohort_builder'
require 'art_service/reports/cohort_struct'

ActiveRecord::Base.logger = Logger.new(IO::NULL) if defined?(ActiveRecord)
Rails.logger = Logger.new(IO::NULL) if defined?(Rails)

output = []
output << "="*70
output << "ART COHORT REPORT ANALYSIS - FRONTEND CALCULATION"
output << "="*70

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
  output << "\n" + "-"*70
  output << "#{quarter_name} (#{dates[:start]} to #{dates[:end]})"
  output << "-"*70
  
  begin
    cohort_struct = ArtService::Reports::CohortStruct.new
    cohort = builder.build(cohort_struct, dates[:start], dates[:end], nil)
    
    # Safe extraction with fallbacks
    cum_reg = begin
      val = cohort.cum_total_registered
      if val.is_a?(Enumerable)
        val.count
      elsif val.nil?
        on_art_val = cohort.total_alive_and_on_art
        defaulted_val = cohort.defaulted
        died_val = cohort.died_total
        transferred_val = cohort.transfered_out
        on_art_count = on_art_val.is_a?(Enumerable) ? on_art_val.count : (on_art_val.to_i rescue 0)
        default_count = defaulted_val.is_a?(Enumerable) ? defaulted_val.count : (defaulted_val.to_i rescue 0)
        died_c = died_val.is_a?(Enumerable) ? died_val.count : (died_val.to_i rescue 0)
        trans_c = transferred_val.is_a?(Enumerable) ? transferred_val.count : (transferred_val.to_i rescue 0)
        on_art_count + default_count + died_c + trans_c
      else
        val.to_i
      end
    end
    
    on_art = begin
      val = cohort.total_alive_and_on_art
      val.is_a?(Enumerable) ? val.count : (val.to_i rescue 0)
    end
    defaulted_count = begin
      val = cohort.defaulted
      val.is_a?(Enumerable) ? val.count : (val.to_i rescue 0)
    end
    died_count = begin
      val = cohort.died_total
      val.is_a?(Enumerable) ? val.count : (val.to_i rescue 0)
    end
    transferred = begin
      val = cohort.transfered_out
      val.is_a?(Enumerable) ? val.count : (val.to_i rescue 0)
    end
    
    results[quarter_name] = {
      cum_total_registered: cum_reg,
      on_art: on_art,
      defaulted: defaulted_count,
      died: died_count,
      transferred: transferred
    }
    
    retention = cum_reg > 0 ? ((on_art.to_f / cum_reg) * 100).round(2) : 0
    default_rate = on_art > 0 ? ((defaulted_count.to_f / on_art) * 100).round(2) : 0
    
    output << "  Cumulative Ever Registered: #{cum_reg}"
    output << "  Total On ART:               #{on_art}"
    output << "  Defaulted:                  #{defaulted_count}"
    output << "  Died:                       #{died_count}"
    output << "  Transferred Out:            #{transferred}"
    output << "  Retention Rate:             #{retention}% (target: ≥90%)"
    output << "  Default Rate:               #{default_rate}% (target: <3%)"
    
  rescue => e
    output << "  ERROR: #{e.class.name} - #{e.message[0..200]}"
    results[quarter_name] = nil
  end
end

# Add summary
output << "\n" + "="*70
output << "SUMMARY: 2025 vs 2026"
output << "="*70

if results['Q1 2025'] && results['Q4 2026']
  q1_25 = results['Q1 2025']
  q4_26 = results['Q4 2026']
  
  reg_growth = q4_26[:cum_total_registered] - q1_25[:cum_total_registered]
  on_art_growth = q4_26[:on_art] - q1_25[:on_art]
  default_growth = q4_26[:defaulted] - q1_25[:defaulted]
  
  reg_pct = q1_25[:cum_total_registered] > 0 ? ((reg_growth.to_f / q1_25[:cum_total_registered]) * 100).round(2) : 0
  
  output << "\nQ1 2025 Baseline → Q4 2026 Current:"
  output << "  Cumulative Registered:  #{q1_25[:cum_total_registered]} → #{q4_26[:cum_total_registered]}  (#{reg_pct > 0 ? '+' : ''}#{reg_pct}% change)"
  output << "  On ART:                 #{q1_25[:on_art]} → #{q4_26[:on_art]}  (#{on_art_growth > 0 ? '+' : ''}#{on_art_growth} patients)"
  output << "  Defaulted:              #{q1_25[:defaulted]} → #{q4_26[:defaulted]}  (#{default_growth > 0 ? '+' : ''}#{default_growth} patients)"
end

output << "\n" + "="*70

# Write to file and display
File.write('/tmp/art_report.txt', output.join("\n"))
puts output.join("\n")
