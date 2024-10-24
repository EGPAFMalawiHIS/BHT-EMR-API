# frozen_string_literal: true

module ArtService
  module Reports
    module Pepfar
      ## Viral Load Coverage Report
      # 1. given the start and end dates, this report will go back 12 months using the end date
      # 2. pick all clients that are due in the mentioned period
      # 3. the picked clients should also include those that are new on ART 6 months before the end date
      # 4. for the sample drawns available pick the latest sample drawn within the reporting period
      # 5. for the results pick the latest result within the reporting period
      # rubocop:disable Metrics/ClassLength
      class ViralLoadCoverage2 < CachedReport
        attr_reader :start_date, :end_date, :occupation, :rebuild

        include Utils
        include CommonSqlQueryUtils

        def initialize(start_date:, end_date:, **kwargs)
          super(start_date:, end_date:, **kwargs)
        end

        def find_report
          report = init_report
          build_report(report)
          report
        end

        def vl_maternal_status(patient_list)
          return { FP: [], FBf: [], FNP: [] } if patient_list.blank?

          pregnant = pregnant_women(patient_list).map { |woman| woman['person_id'].to_i }
          return { FP: pregnant, FBf: [], FNP: [] } if (patient_list - pregnant).blank?

          feeding = breast_feeding(patient_list - pregnant).map { |woman| woman['person_id'].to_i }
          not_pregnant = patient_list - pregnant - feeding
          {
            FP: pregnant,
            FBf: feeding,
            FNP: not_pregnant
          }
        end

        # rubocop:disable Metrics/AbcSize
        # rubocop:disable Metrics/CyclomaticComplexity
        # rubocop:disable Metrics/MethodLength
        def process_due_people
          @clients = []
          start = Time.now
          results = patients_on_art
          # get all clients that are females from results
          @maternal_status = vl_maternal_status(results.map do |patient|
                                                  patient['patient_id'] if patient['gender'] == 'F'
                                                end.compact)
          if @type.blank? || @type == 'poc'
            Parallel.each(results, in_threads: 20) do |patient|
              process_client_eligibility(patient)
            end
          end
          results.each { |patient| process_client_eligibility(patient) } if @type == 'emastercard'
          Rails.logger.info "Time taken for VL Coverage to process #{results.length} clients: #{Time.now - start} seconds.
                            These are the clients returned: #{@clients.length}"
          @clients
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/CyclomaticComplexity
        # rubocop:enable Metrics/MethodLength

        ##
        # Find all patients that are on treatment with at least one VL before end of reporting period.
        # rubocop:disable Metrics/AbcSize
        # rubocop:disable Metrics/MethodLength
        def find_patients_with_viral_load(clients)
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT orders.patient_id,
                   disaggregated_age_group(patient.birthdate,
                                                  DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS age_group,
                   patient.birthdate,
                   LEFT(patient.gender, 1) gender,
                   patient_identifier.identifier AS arv_number,
                   orders.start_date AS order_date,
                   COALESCE(orders.discontinued_date, orders.start_date) AS sample_draw_date,
                   COALESCE(reason_for_test_value.name, reason_for_test.value_text) AS reason_for_test,
                   result.value_modifier AS result_modifier,
                   COALESCE(result.value_numeric, result.value_text) AS result_value
            FROM orders
            INNER JOIN person patient ON patient.person_id = orders.patient_id AND patient.voided = 0
            INNER JOIN order_type
              ON order_type.order_type_id = orders.order_type_id
              AND order_type.name = 'Lab'
              AND order_type.retired = 0
            INNER JOIN concept_name
              ON concept_name.concept_id = orders.concept_id
              AND concept_name.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)', 'Plasma')
              AND concept_name.voided = 0
            LEFT JOIN obs AS reason_for_test
              ON reason_for_test.order_id = orders.order_id
              AND reason_for_test.concept_id IN (SELECT concept_id FROM concept_name WHERE name LIKE 'Reason for test' AND voided = 0)
              AND reason_for_test.voided = 0
            LEFT JOIN concept_name AS reason_for_test_value
              ON reason_for_test_value.concept_id = reason_for_test.value_coded
              AND reason_for_test_value.voided = 0
            LEFT JOIN obs AS result
              ON result.order_id = orders.order_id
              AND result.concept_id IN (SELECT concept_id FROM concept_name WHERE name LIKE 'HIV Viral load' AND voided = 0)
              AND result.voided = 0
              AND (result.value_text IS NOT NULL OR result.value_numeric IS NOT NULL)
            INNER JOIN (
              /* Get the latest order dates for each patient */
              SELECT orders.patient_id, MAX(orders.start_date) AS start_date
              FROM orders
              INNER JOIN order_type
                ON order_type.order_type_id = orders.order_type_id
                AND order_type.name = 'Lab'
                AND order_type.retired = 0
              INNER JOIN concept_name
                ON concept_name.concept_id = orders.concept_id
                AND concept_name.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)', 'Plasma')
                AND concept_name.voided = 0
              WHERE orders.start_date < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
                AND orders.start_date >= DATE(#{ActiveRecord::Base.connection.quote(start_date)}) - INTERVAL 12 MONTH
                AND orders.voided = 0
              GROUP BY orders.patient_id
            ) AS latest_patient_order_date
              ON latest_patient_order_date.patient_id = orders.patient_id
              AND latest_patient_order_date.start_date = orders.start_date
            LEFT JOIN patient_identifier
              ON patient_identifier.patient_id = orders.patient_id
              AND patient_identifier.identifier_type IN (#{pepfar_patient_identifier_type.to_sql})
              AND patient_identifier.voided = 0
            WHERE orders.start_date < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
              AND orders.start_date >= DATE(#{ActiveRecord::Base.connection.quote(start_date)}) - INTERVAL 12 MONTH
              AND orders.voided = 0
              AND orders.patient_id IN (#{clients.push(0).join(',')})
            GROUP BY orders.patient_id
          SQL
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/MethodLength

        private

        # rubocop:disable Metrics/AbcSize
        # rubocop:disable Metrics/MethodLength
        # rubocop:disable Metrics/CyclomaticComplexity
        # rubocop:disable Metrics/PerceivedComplexity
        # rubocop:disable Layout/LineLength
        def process_client_eligibility(patient)
          patient['maternal_status'] =
            if @maternal_status[:FP].include?(patient['patient_id'])
              'FP'
            else
              (@maternal_status[:FBf].include?(patient['patient_id']) ? 'FBf' : nil)
            end
          return if !patient['defaulter_date'].blank? && (patient['defaulter_date'] < end_date - 12.months)
          return if patient['art_start_date'].blank?
          return if patient['art_start_date'].to_date > end_date - 6.months
          return if remove_adverse_outcome_patient?(patient)

          @clients << patient
        end

        def remove_adverse_outcome_patient?(patient)
          return false if patient['state'] == 'On antiretrovirals'

          last_date = patient['vl_order_date'] || patient['art_start_date']
          if patient['vl_order_date'].present? && last_date.to_date >= start_date && last_date.to_date <= end_date
            return false
          end

          length = 12
          length = 6 if patient['maternal_status'] == 'FP'
          length = 6 if patient['maternal_status'] == 'FBf'
          length = 6 if patient['current_regimen'].to_s.match(/P/i)
          length = 6 if patient['diff_in_months'] < 12 && patient['vl_order_date'].blank?

          if patient['vl_order_date'] && patient['vl_order_date'].to_date >= end_date - 12.months && patient['vl_order_date'].to_date <= end_date
            return false
          end
          return false if last_date.to_date + length.months < (patient['state'] == 'Defaulted' ? end_date.to_date : patient['outcome_date'].to_date)

          true
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/MethodLength
        # rubocop:enable Metrics/CyclomaticComplexity
        # rubocop:enable Metrics/PerceivedComplexity
        # rubocop:enable Layout/LineLength

        # rubocop:disable Metrics/AbcSize
        # rubocop:disable Metrics/MethodLength
        def pregnant_women(patient_list)
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT o.person_id, o.value_coded
            FROM obs o
            LEFT JOIN obs a ON a.person_id = o.person_id AND a.obs_datetime > o.obs_datetime AND a.concept_id IN (#{pregnant_concepts.to_sql}) AND a.voided = 0
            AND a.obs_datetime >= DATE(#{ActiveRecord::Base.connection.quote(start_date)}) AND a.obs_datetime < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
            WHERE a.obs_id is null
              AND o.obs_datetime >= DATE(#{ActiveRecord::Base.connection.quote(start_date)})
              AND o.obs_datetime < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
              AND o.voided = 0
              AND o.concept_id in (#{pregnant_concepts.to_sql})
              AND o.person_id IN (#{patient_list.join(',')})
              AND o.value_coded IN (#{yes_concepts.join(',')})
            GROUP BY o.person_id
          SQL
        end

        def breast_feeding(patient_list)
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT o.person_id, o.value_coded
            FROM obs o
            LEFT JOIN obs a ON a.person_id = o.person_id AND a.obs_datetime > o.obs_datetime AND a.concept_id IN (#{breast_feeding_concepts.to_sql}) AND a.voided = 0
            AND a.obs_datetime >= DATE(#{ActiveRecord::Base.connection.quote(start_date)}) AND a.obs_datetime < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
            WHERE a.obs_id is null
              AND o.obs_datetime >= DATE(#{ActiveRecord::Base.connection.quote(start_date)})
              AND o.obs_datetime < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
              AND o.voided = 0
              AND o.concept_id IN (#{breast_feeding_concepts.to_sql})
              AND o.person_id IN (#{patient_list.join(',')})
              AND o.value_coded IN (#{yes_concepts.join(',')})
            GROUP BY o.person_id
          SQL
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/MethodLength

        def build_report(report)
          refresh_outcomes_table if rebuild
          load_tx_curr_into_report(report, create_patients_alive_and_on_art_query)
          clients = process_due_people
          clients.each do |patient|
            report[patient['age_group']][patient['gender'].to_sym][:due_for_vl] << patient['patient_id']
          end
          load_patient_tests_into_report(report, clients.map { |patient| patient['patient_id'] })
        end

        def refresh_outcomes_table
          CohortBuilder.new(outcomes_definition: 'pepfar')
                       .init_temporary_tables(@start_date, @end_date, @occupation)
        end

        def create_patients_alive_and_on_art_query
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT tpo.patient_id, LEFT(tesd.gender, 1) AS gender, disaggregated_age_group(tesd.birthdate, DATE('#{end_date.to_date}')) age_group
            FROM temp_patient_outcomes tpo
            INNER JOIN temp_earliest_start_date tesd ON tesd.patient_id = tpo.patient_id
            WHERE tpo.pepfar_cum_outcome = 'On antiretrovirals'
          SQL
        end

        def load_tx_curr_into_report(report, patients)
          report.each_key do |age_group|
            %i[M F].each do |gender|
              report[age_group][gender][:tx_curr] ||= []
              report[age_group][gender][:tx_curr] = populate_tx_curr(patients, age_group, gender) || []
            end
          end
        end

        def populate_tx_curr(patients, age_group, gender)
          patients.select do |patient|
            (patient['age_group'] == age_group && patient['gender'].to_sym == gender) && patient['patient_id']
          end&.map { |patient| patient['patient_id'] }
        end

        # rubocop:disable Metrics/AbcSize
        # rubocop:disable Metrics/MethodLength
        def load_patient_tests_into_report(report, clients)
          find_patients_with_viral_load(clients).each do |patient|
            age_group = patient['age_group']
            gender = patient['gender'].to_sym
            reason_for_test = (patient['reason_for_test'] || 'Routine').match?(/Routine/i) ? :routine : :targeted

            report[age_group][gender][:drawn][reason_for_test] << patient['patient_id']
            next unless patient['result_value']

            if patient['result_value'].casecmp?('LDL')
              report[age_group][gender][:low_vl][reason_for_test] << patient['patient_id']
            elsif patient['result_value'].to_i < 1000
              report[age_group][gender][:low_vl][reason_for_test] << patient['patient_id']
            else
              report[age_group][gender][:high_vl][reason_for_test] << patient['patient_id']
            end
          end
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/MethodLength

        ## This method prepares the response structure for the report
        def init_report
          pepfar_age_groups.each_with_object({}) do |age_group, report|
            report[age_group] = %i[F M].each_with_object({}) do |gender, hash|
              hash[gender] = {
                due_for_vl: [],
                drawn: { routine: [], targeted: [] },
                high_vl: { routine: [], targeted: [] },
                low_vl: { routine: [], targeted: [] }
              }
            end
          end
        end

        def due_for_viral_load
          ActiveRecord::Base.connection.select_all <<~SQL
            (#{find_patients_with_overdue_viral_load}) UNION (#{find_patients_due_for_initial_viral_load})
          SQL
        end

        def adverse_outcomes
          @adverse_outcomes ||= ActiveRecord::Base.connection.select_all(
            <<~SQL
              SELECT pws.program_workflow_state_id state
              FROM program_workflow pw
              INNER JOIN concept_name pcn ON pcn.concept_id = pw.concept_id AND pcn.concept_name_type = 'FULLY_SPECIFIED' AND pcn.voided = 0
              INNER JOIN program_workflow_state pws ON pws.program_workflow_id = pw.program_workflow_id AND pws.retired = 0
              INNER JOIN concept_name cn ON cn.concept_id = pws.concept_id AND cn.concept_name_type = 'FULLY_SPECIFIED' AND cn.voided = 0
              WHERE pw.program_id = 1 AND pw.retired = 0 AND pws.terminal = 1
            SQL
          ).map { |state| state['state'] }
        end

        def patients_on_art
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              cum.patient_id,
              disaggregated_age_group(e.birthdate, DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS age_group,
              regimen.regimen_category current_regimen,
              e.earliest_start_date art_start_date,
              if(cum.pepfar_cum_outcome = 'Defaulted', cum.pepfar_outcome_date, null) defaulter_date,
              e.birthdate,
              LEFT(e.gender,1) gender,
              pid.identifier AS arv_number,
              cum.pepfar_cum_outcome state,
              cum.pepfar_outcome_date outcome_date,
              current_order.start_date vl_order_date,
              st.start_date recorded_state_start_date,
              TIMESTAMPDIFF(month, e.earliest_start_date, '2024-03-31') diff_in_months
            FROM temp_patient_outcomes cum
            INNER JOIN temp_earliest_start_date e ON e.patient_id = cum.patient_id
            INNER JOIN temp_max_patient_state st ON st.patient_id = cum.patient_id
            INNER JOIN (
              SELECT prescriptions.patient_id, regimens.name AS regimen_category, prescriptions.drugs, prescriptions.prescription_date
              FROM (
                SELECT tcm.patient_id, GROUP_CONCAT(DISTINCT(tcm.drug_id) ORDER BY tcm.drug_id ASC) AS drugs, DATE(tcm.start_date) prescription_date
                FROM temp_current_medication tcm
                GROUP BY tcm.patient_id
              ) AS prescriptions
              LEFT JOIN (
                SELECT GROUP_CONCAT(drug.drug_id ORDER BY drug.drug_id ASC) AS drugs, regimen_name.name AS name
                FROM moh_regimen_combination AS combo
                INNER JOIN moh_regimen_combination_drug AS drug USING (regimen_combination_id)
                INNER JOIN moh_regimen_name AS regimen_name USING (regimen_name_id)
                GROUP BY combo.regimen_combination_id
              ) AS regimens ON regimens.drugs = prescriptions.drugs
            ) regimen ON regimen.patient_id = cum.patient_id
            LEFT JOIN (#{current_occupation_query}) a ON a.person_id = cum.patient_id
            LEFT JOIN patient_identifier pid ON pid.patient_id = cum.patient_id AND pid.identifier_type IN (#{pepfar_patient_identifier_type.to_sql}) AND pid.voided = 0
            LEFT JOIN (
              SELECT ab.patient_id, MAX(ab.start_date) start_date
              FROM orders ab
              INNER JOIN concept_name
                ON concept_name.concept_id = ab.concept_id
                AND concept_name.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)', '50:50 Normal Plasma')
                AND concept_name.voided = 0
              LEFT OUTER JOIN orders b ON ab.patient_id = b.patient_id
                AND ab.order_id = b.order_id
                AND ab.start_date < b.start_date
                AND b.voided = 0
              WHERE b.patient_id IS NULL AND ab.voided = 0 AND ab.order_type_id = 4 AND ab.start_date < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
              GROUP BY ab.patient_id
            ) current_order ON current_order.patient_id = cum.patient_id
            WHERE cum.step > 0 AND e.date_enrolled < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
              AND ((cum.pepfar_cum_outcome != 'On antiretrovirals' AND cum.pepfar_outcome_date >= (DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH)) OR cum.pepfar_cum_outcome = 'On antiretrovirals')
            GROUP BY cum.patient_id
          SQL
        end

        def extra_information(patient_id)
          ActiveRecord::Base.connection.select_one <<~SQL
            SELECT patient_current_regimen(#{patient_id}, DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS current_regimen,
            date_antiretrovirals_started(#{patient_id}, DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS art_start_date,
            current_pepfar_defaulter_date(#{patient_id}, DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS defaulter_date
          SQL
        end

        def yes_concepts
          @yes_concepts ||= ConceptName.where(name: 'Yes').select(:concept_id).map do |record|
            record['concept_id'].to_i
          end
        end

        def pregnant_concepts
          @pregnant_concepts ||= ConceptName.where(name: ['Is patient pregnant?', 'patient pregnant'])
                                            .select(:concept_id)
        end

        def breast_feeding_concepts
          @breast_feeding_concepts ||= ConceptName.where(name: ['Breast feeding?', 'Breast feeding', 'Breastfeeding'])
                                                  .select(:concept_id)
        end

        def encounter_types
          @encounter_types ||= EncounterType.where(name: ['HIV CLINIC CONSULTATION', 'HIV STAGING'])
                                            .select(:encounter_type_id)
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
