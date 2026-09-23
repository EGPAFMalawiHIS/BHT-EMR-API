#!/usr/bin/env ruby
# ART Cohort Report Data Retrieval Script
# Usage: rails runner art_cohort_report_2025.rb
# Purpose: Fetch and display ART cohort indicators for Q1 2025 onwards

require 'json'
require 'csv'

class ArtCohortReportAnalyzer
  QUARTERS = {
    'Q1 2025' => { start: Date.new(2025, 1, 1), end: Date.new(2025, 3, 31) },
    'Q2 2025' => { start: Date.new(2025, 4, 1), end: Date.new(2025, 6, 30) },
    'Q3 2025' => { start: Date.new(2025, 7, 1), end: Date.new(2025, 9, 30) },
    'Q4 2025' => { start: Date.new(2025, 10, 1), end: Date.new(2025, 12, 31) }
  }

  def initialize
    @program = Program.find_by(name: 'HIV PROGRAM')
    @report_service = ReportService.new(program_id: @program.id, overwrite_mode: false)
  end

  def fetch_all_quarters
    results = {}
    QUARTERS.each do |quarter_name, dates|
      puts "\n" + "="*60
      puts "Fetching #{quarter_name} (#{dates[:start]} to #{dates[:end]})"
      puts "="*60
      
      begin
        cohort_data = @report_service.cohort_disaggregated(
          quarter: quarter_name,
          age_group: 'All',
          start_date: dates[:start],
          end_date: dates[:end],
          rebuild: false,
          init: false
        )
        
        results[quarter_name] = extract_indicators(cohort_data, dates)
        print_quarter_results(quarter_name, results[quarter_name])
      rescue => e
        puts "ERROR fetching #{quarter_name}: #{e.message}"
        results[quarter_name] = nil
      end
    end
    
    results
  end

  def extract_indicators(cohort_data, dates)
    {
      period: "#{dates[:start]} to #{dates[:end]}",
      cum_total_registered: cohort_data.cum_total_registered&.count || 0,
      total_alive_and_on_art: cohort_data.total_alive_and_on_art&.count || 0,
      defaulted: cohort_data.defaulted&.count || 0,
      timestamp: Time.now.iso8601
    }
  end

  def print_quarter_results(quarter, data)
    return unless data
    
    puts "\n[#{quarter}]"
    puts "  Period: #{data[:period]}"
    puts "  Cumulative Ever Registered: #{number_with_comma(data[:cum_total_registered])}"
    puts "  Total Alive and On ART: #{number_with_comma(data[:total_alive_and_on_art])}"
    puts "  Defaulted: #{number_with_comma(data[:defaulted])}"
    
    # Calculate metrics
    if data[:cum_total_registered] > 0
      retention = (data[:total_alive_and_on_art].to_f / data[:cum_total_registered] * 100).round(2)
      puts "  Retention Rate: #{retention}%"
    end
    
    if data[:total_alive_and_on_art] > 0
      default_rate = (data[:defaulted].to_f / data[:total_alive_and_on_art] * 100).round(2)
      puts "  Default Rate: #{default_rate}%"
    end
  end

  def generate_csv_report(results)
    filename = "art_cohort_report_#{Time.now.strftime('%Y%m%d_%H%M%S')}.csv"
    
    CSV.open(filename, 'w') do |csv|
      csv << ['Quarter', 'Period', 'Cumulative Ever Registered', 'Total Alive & On ART', 
              'Defaulted', 'Retention %', 'Default Rate %']
      
      results.each do |quarter, data|
        next unless data
        
        retention = data[:cum_total_registered] > 0 ? 
          (data[:total_alive_and_on_art].to_f / data[:cum_total_registered] * 100).round(2) : 0
        default_rate = data[:total_alive_and_on_art] > 0 ? 
          (data[:defaulted].to_f / data[:total_alive_and_on_art] * 100).round(2) : 0
        
        csv << [
          quarter,
          data[:period],
          data[:cum_total_registered],
          data[:total_alive_and_on_art],
          data[:defaulted],
          retention,
          default_rate
        ]
      end
    end
    
    puts "\n✓ CSV Report saved to: #{filename}"
    filename
  end

  def generate_json_report(results)
    filename = "art_cohort_report_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
    
    report = {
      metadata: {
        generated_at: Time.now.iso8601,
        program: 'HIV PROGRAM',
        facility: get_facility_name,
        quarters: QUARTERS.keys
      },
      data: results
    }
    
    File.write(filename, JSON.pretty_generate(report))
    puts "✓ JSON Report saved to: #{filename}"
    filename
  end

  def generate_analysis_summary(results)
    summary = "\n" + "="*60
    summary += "\n ART COHORT ANALYSIS SUMMARY (2025)\n"
    summary += "="*60 + "\n"
    
    # Overall statistics
    valid_results = results.compact
    return summary + "No data available\n" if valid_results.empty?
    
    first_quarter = valid_results.first
    last_quarter = valid_results.last
    
    summary += "\nBASELINE (Q1 2025):\n"
    if first_quarter
      summary += "  • Total Cumulative Registered: #{number_with_comma(first_quarter[1][:cum_total_registered])}\n"
      summary += "  • Alive & On ART: #{number_with_comma(first_quarter[1][:total_alive_and_on_art])}\n"
      summary += "  • Defaulted: #{number_with_comma(first_quarter[1][:defaulted])}\n"
    end
    
    summary += "\nTRENDS ACROSS 2025:\n"
    
    # Calculate growth metrics
    if valid_results.size > 1
      qoq_changes = {}
      valid_results.each_cons(2) do |prev_q, curr_q|
        quarter_name = valid_results.key(curr_q)
        prev_quarter_name = valid_results.key(prev_q)
        
        prev_data = prev_q[1]
        curr_data = curr_q[1]
        
        registered_change = curr_data[:cum_total_registered] - prev_data[:cum_total_registered]
        art_change = curr_data[:total_alive_and_on_art] - prev_data[:total_alive_and_on_art]
        default_change = curr_data[:defaulted] - prev_data[:defaulted]
        
        summary += "\n  #{prev_quarter_name} → #{quarter_name}:\n"
        summary += "    - Cumulative Registered Growth: +#{registered_change} patients\n"
        summary += "    - Alive & On ART Change: #{art_change > 0 ? '+' : ''}#{art_change} patients\n"
        summary += "    - Defaulted Change: #{default_change > 0 ? '+' : ''}#{default_change} patients\n"
      end
    end
    
    summary += "\nKEY PERFORMANCE INDICATORS:\n"
    summary += "  • Target Retention Rate: ≥90%\n"
    summary += "  • Target Default Rate: <3%\n"
    summary += "  • Target On Treatment: ≥90% of cumulative\n"
    
    summary += "\n" + "="*60 + "\n"
    summary
  end

  private

  def number_with_comma(num)
    num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def get_facility_name
    facility = Location.find_by(location_id: GlobalPropertyService.get_location_id)
    facility&.name || 'All Facilities'
  end
end

# Main execution
if __FILE__ == $0
  puts "Starting ART Cohort Report Analysis..."
  analyzer = ArtCohortReportAnalyzer.new
  
  results = analyzer.fetch_all_quarters
  
  # Generate reports
  analyzer.generate_csv_report(results)
  analyzer.generate_json_report(results)
  puts analyzer.generate_analysis_summary(results)
  
  puts "\n✓ Analysis complete!"
end
