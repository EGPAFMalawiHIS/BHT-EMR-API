# frozen_string_literal: true

module CxcaService
  module Reports
    module Clinic
      class MonthlyScreenReport
        include Utils

        attr_accessor :start_date, :end_date, :report

        CxCa_PROGRAM = Program.find_by_name 'CxCa program'

        TX_GROUPS = {
          first_time_screened: ['initial screening', 'referral'],
          rescreened_after_prev_visit: ['subsequent screening'],
          post_treatment_followup: ['one year subsequent check-up after treatment', 'problem visit after treatment']
        }.freeze

        CxCa_TX_OUTCOMES = {
           positive: ['via positive', 'hpv positive', 'pap smear abnormal', 'visible lesion'],
           negative: ['via negative', 'hpv negative', 'pap smear normal', 'no visible lesion', 'other gynae'],
          suspected: ['suspect cancer']
        }.freeze

        TREATMENTS = %i[thermocoagulation cryotherapy leep].freeze

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = start_date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @end_date = end_date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @report = {}
        end

        def data
          patients = fetch_query
          init_report patients
          get_totals patients
          report
        end

        private

        def init_report(query)
          report['data'] ||= {}
          TX_GROUPS.each do |(name, values)|
            report['data'][name] ||= []
            age_groups.each do |age_group|
              x = query.select { |q| q['reason_for_visit'].to_s.downcase.in?(values) && q['age_group'] == age_group }
              report['data'][name].push(get_indicators(x, age_group))
            end
            x2 = query.select { |q| q['reason_for_visit'].to_s.downcase.in?(values) && q['age_group'].in?(fifty_plus) }
            report['data'][name].push(get_indicators(x2, '50 plus years'))
          end
        end

        def get_totals(query)
          report['totals'] ||= {}
          report['totals']['total_screened'] = query&.map { |q| q['person_id'] }&.uniq
          report['totals']['total_negative'] = query.select do |q|
                                                 q['screening_results']&.to_s&.downcase&.in?(CxCa_TX_OUTCOMES[:negative])
                                               end&.map { |q| q['person_id'] }&.uniq
          report['totals']['total_via_plus_eligible_for_same_day_tx'] = query.select do |d|
            d['via_result'].to_s.downcase == 'VIA positive' || d['screening_results'] == 'VIA positive' && (d['tx_option'] == 'Same day treatment')
          end.uniq
          report['totals']['total_positive'] = query.select do |q|
                                                 q['screening_results']&.to_s&.downcase&.in?(CxCa_TX_OUTCOMES[:positive])
                                               end&.map { |q| q['person_id'] }&.uniq
          report['totals']['total_suspect_cancer'] = query.select do |q|
                                                       q['screening_results']&.to_s&.downcase&.in?(CxCa_TX_OUTCOMES[:suspected])
                                                     end&.map { |q| q['person_id'] }&.uniq
        end

        def get_indicators(x, age_group)
          groups = {}
          groups['age_group'] = age_group
          CxCa_TX_OUTCOMES.each do |(name, values)|
            groups[name] = x.select do |q|
                             q['screening_results'].to_s.downcase.in?(values)
                           end&.map { |q| q['person_id'] }&.uniq
          end
          groups['for_same_day_tx'] = x.select do |d|
                                        d['tx_option'] == 'Same day treatment'
                                      end&.map { |q| q['person_id'] }&.uniq
          groups
        end

        def fetch_query
          Person.connection.select_all(
            Person.joins(patient: :encounters)
            .where(encounter: { program_id: CxCa_PROGRAM.id, encounter_datetime: @start_date..@end_date })
            .joins(<<~SQL)
              LEFT JOIN obs reason_for_visit ON reason_for_visit.person_id = person.person_id
                  AND reason_for_visit.voided = 0
                  AND reason_for_visit.concept_id = #{concept('Reason for visit').concept_id}
                  LEFT JOIN concept_name reason_name ON reason_name.concept_id = reason_for_visit.value_coded
                  AND reason_name.voided = 0
                  LEFT JOIN obs via_results ON via_results.person_id = person.person_id
                  AND via_results.voided = 0
                  AND via_results.concept_id = 9514
                  LEFT JOIN concept_name result_name ON result_name.concept_id = via_results.value_coded
                  AND result_name.voided = 0
                  LEFT JOIN obs treatment_option ON treatment_option.person_id = person.person_id
                  AND treatment_option.voided = 0
                  AND treatment_option.concept_id = #{concept('Directly observed treatment option').concept_id}
                  LEFT JOIN concept_name tx_option_name ON tx_option_name.concept_id = treatment_option.value_coded
                  AND treatment_option.voided = 0
                  LEFT JOIN obs treatment ON treatment.person_id = person.person_id
                  AND treatment.voided = 0
                  AND treatment.concept_id = #{concept('Treatment').concept_id}
                  LEFT JOIN obs screening_results ON screening_results.person_id = person.person_id
                  AND screening_results.voided = 0
                  AND screening_results.concept_id = #{concept('Screening results').concept_id}
                  LEFT JOIN concept_name screening_results_name ON screening_results_name.concept_id = screening_results.value_coded
                  AND screening_results_name.voided = 0
            SQL
              .group('person.person_id')
              .select("disaggregated_age_group(person.birthdate, DATE('#{@end_date.to_date}')) AS age_group, person.person_id, reason_name.name AS reason_for_visit, max(treatment.value_text) AS treatment, result_name.name AS via_result, screening_results_name.name as screening_results, tx_option_name.name AS tx_option")
              .to_sql
          ).to_a
        end
      end
    end
  end
end
