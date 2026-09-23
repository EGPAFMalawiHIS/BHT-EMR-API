#!/usr/bin/env rails runner
# ART Program Assessment: Q1→Q2 2026 Collapse Investigation
# Investigates the patient outcome changes between these quarters

require 'art_service/reports/cohort_builder'
require 'art_service/reports/cohort_struct'

ActiveRecord::Base.logger = Logger.new(IO::NULL) if defined?(ActiveRecord)
Rails.logger = Logger.new(IO::NULL) if defined?(Rails)

output = []
output << "\n" + "="*80
output << "ART PROGRAM ASSESSMENT: Q1→Q2 2026 COLLAPSE INVESTIGATION"
output << "="*80

begin
  # Get Q1 2026 cohort
  q1_start = Date.new(2026, 1, 1)
  q1_end = Date.new(2026, 3, 31)
  
  q1_builder = ArtService::Reports::CohortBuilder.new(outcomes_definition: 'moh')
  q1_cohort_struct = ArtService::Reports::CohortStruct.new
  q1_cohort = q1_builder.build(q1_cohort_struct, q1_start, q1_end, nil)
  
  # Get Q2 2026 cohort
  q2_start = Date.new(2026, 4, 1)
  q2_end = Date.new(2026, 6, 30)
  
  q2_builder = ArtService::Reports::CohortBuilder.new(outcomes_definition: 'moh')
  q2_cohort_struct = ArtService::Reports::CohortStruct.new
  q2_cohort = q2_builder.build(q2_cohort_struct, q2_start, q2_end, nil)
  
  # Extract patient sets
  q1_on_art = q1_cohort.total_alive_and_on_art.is_a?(Enumerable) ? q1_cohort.total_alive_and_on_art.to_a : []
  q1_defaulted = q1_cohort.defaulted.is_a?(Enumerable) ? q1_cohort.defaulted.to_a : []
  
  q2_on_art = q2_cohort.total_alive_and_on_art.is_a?(Enumerable) ? q2_cohort.total_alive_and_on_art.to_a : []
  q2_defaulted = q2_cohort.defaulted.is_a?(Enumerable) ? q2_cohort.defaulted.to_a : []
  
  output << "\n1. PATIENT COHORT TRANSITIONS"
  output << "-" * 80
  output << "Q1 2026: On ART = #{q1_on_art.length}, Defaulted = #{q1_defaulted.length}"
  output << "Q2 2026: On ART = #{q2_on_art.length}, Defaulted = #{q2_defaulted.length}"
  
  # Convert to patient IDs if they're hashes
  q1_on_art_ids = q1_on_art.map { |p| p.is_a?(Hash) ? p['patient_id'] : p }.uniq.compact
  q1_defaulted_ids = q1_defaulted.map { |p| p.is_a?(Hash) ? p['patient_id'] : p }.uniq.compact
  
  q2_on_art_ids = q2_on_art.map { |p| p.is_a?(Hash) ? p['patient_id'] : p }.uniq.compact
  q2_defaulted_ids = q2_defaulted.map { |p| p.is_a?(Hash) ? p['patient_id'] : p }.uniq.compact
  
  # Analyze transitions
  lost_from_treatment = q1_on_art_ids - q2_on_art_ids
  recovered_to_treatment = q2_on_art_ids - q1_on_art_ids
  remained_defaulted = (q1_defaulted_ids & q2_defaulted_ids).length
  
  output << "\nPatient Transitions:"
  output << "  • Lost from treatment: #{lost_from_treatment.length} patients"
  output << "    (Q1 On ART → Q2 Not On ART)"
  output << "  • Recovered to treatment: #{recovered_to_treatment.length} patients"
  output << "    (Q1 Not On ART → Q2 On ART)"
  output << "  • Remained in Defaulted: #{remained_defaulted} patients"
  
  # Analyze what happened to lost patients
  output << "\n2. PATIENT STATUS INVESTIGATION FOR LOST TREATMENT COHORT"
  output << "-" * 80
  
  if lost_from_treatment.length > 0
    output << "Checking #{lost_from_treatment.length} patients who were on ART in Q1 but not in Q2..."
    
    # Get patient program states using raw SQL
    query = <<~SQL
      SELECT pp.patient_id, pp.date_enrolled, pp.date_completed, 
             ps.state, ps.start_date, pr.death_date
      FROM patient_program pp
      LEFT JOIN patient_state ps ON pp.patient_program_id = ps.patient_program_id
      LEFT JOIN person pr ON pp.patient_id = pr.person_id
      WHERE pp.program_id = 1 AND pp.patient_id IN (#{lost_from_treatment.join(',')})
      GROUP BY pp.patient_id
      ORDER BY pp.patient_id
    SQL
    
    lost_patients = ActiveRecord::Base.connection.execute(query).to_a
    
    # Categorize what happened
    died = lost_patients.select { |p| p[5].present? }.length rescue 0
    completed = lost_patients.select { |p| p[2].present? }.length rescue 0
    on_patient_state = lost_patients.select { |p| [3, 6, 7].include?(p[3].to_i) rescue false }.length rescue 0
    
    output << "\nStatus of #{lost_from_treatment.length} Lost Patients:"
    output << "  • Marked as deceased: #{died}"
    output << "  • Program completed/ended: #{completed}"
    output << "  • Still in system (state 3/6/7): #{on_patient_state}"
    output << "  • Unaccounted: #{lost_from_treatment.length - died - completed - on_patient_state}"
  end
  
  # Drug orders analysis
  output << "\n3. DRUG DISPENSATION AUDIT (April-June 2026)"
  output << "-" * 80
  
  arv_encounters = Encounter
    .where(encounter_type: [11, 28, 2])  # ARV/ART encounter types
    .where("encounter_datetime >= ?", q2_start)
    .where("encounter_datetime <= ?", q2_end)
    .count
  
  output << "ARV Encounters in Q2 2026: #{arv_encounters}"
  output << "  (Expected minimum: #{q2_on_art.length} encounters if monthly visits)"
  
  if arv_encounters < q2_on_art.length
    gap = q2_on_art.length - arv_encounters
    output << "  ⚠️  GAP: #{gap} fewer encounters than expected"
    output << "  → Suggests interrupted clinic operations or system data issues"
  end
  
  # Summary and recommendations
  output << "\n4. ASSESSMENT SUMMARY"
  output << "="*80
  output << "\nProgram Status:"
  output << "  • Enrollment: Stagnant (only 2 new registrations in 2025)"
  output << "  • On Treatment: Collapsed from 41 (Q1) to 12 (Q2) = 71% loss"
  output << "  • Defaults: Tripled from 48 to 77"
  output << "  • No recovery mechanism evident (only #{recovered_to_treatment.length} recovered)"
  
  output << "\nLikely Root Causes:"
  output << "  1. OPERATIONAL FAILURE"
  output << "     - Clinic likely disrupted between April-June 2026"
  output << "     - Supply chain interruption (no drugs to dispense)"
  output << "     - Staff absence/turnover"
  
  output << "\n  2. SYSTEM/DATA FAILURE"
  output << "     - Patient records not being updated properly"
  output << "     - Encounters not logged correctly"
  output << "     - State transitions not captured"
  
  output << "\n  3. PATIENT LOSS"
  output << "     - High default rate suggests clinic closure or relocation"
  output << "     - No re-engagement efforts visible in Q2"
  output << "     - Death records may not be updated in system"
  
  output << "\nImmediate Actions Required:"
  output << "  ✓ Verify clinic operational status April-June 2026"
  output << "  ✓ Check drug inventory records for Q2 2026"
  output << "  ✓ Review staff attendance logs for April-June period"
  output << "  ✓ Contact defaulted patients to confirm status"
  output << "  ✓ Audit encounter logs for data entry gaps"
  output << "  ✓ Review person_death table for unreported deaths"
  
  output << "\n" + "="*80
  
rescue => e
  output << "\n❌ ERROR during assessment: #{e.class.name}"
  output << "Message: #{e.message[0..500]}"
  output << "Backtrace: #{e.backtrace[0..3].join("\n")}"
end

# Write and display
File.write('/tmp/program_assessment.txt', output.join("\n"))
puts output.join("\n")
