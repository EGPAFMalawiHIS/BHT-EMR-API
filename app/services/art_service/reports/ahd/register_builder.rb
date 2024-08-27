# frozen_string_literal: true

include ModelUtils

module ArtService
  module Reports
    module Ahd
      class RegisterBuilder
        attr_reader :start_date, :end_date

        def initialize(start_date:, end_date:, relation: Patient.all)
          @start_date = start_date.to_date&.beginning_of_day
          @end_date = end_date.to_date&.end_of_day
          @relation = relation.extending(Scopes)
          @hiv_program = Program.find_by(name: 'HIV Program')
        end

        def register
          ahd_encounter = EncounterType.find_by_name('SYMPTOM SCREENING')

          @relation.joins(encounters: [:observations])
                   .joins(:person)
                   .where(encounter: { program_id: @hiv_program.id })
                   .where(encounter: { encounter_datetime: start_date...end_date })
                   .where(encounter: { encounter_type: ahd_encounter.encounter_type_id })
                   .group('patient.patient_id')
                   .select('patient.patient_id')
                   .select('TIMESTAMPDIFF(YEAR, person.birthdate, CURDATE()) AS age')
        end

        module Scopes
          def run(sql)
            query = ActiveRecord::Base.connection.select_all(sql.to_sql)
            query.rows.map { |row| query.columns.zip(row).to_h }
          end

          def genders
            select('person.gender AS gender')
              .merge(female_breastfeeding)
              .merge(female_pregnant)
          end

          def ahd_outcomes(end_date)
            select("pepfar_patient_outcome(patient.patient_id, #{end_date}) AS outcome")
          end

          def outcome_date(start_date)
            select('latest_outcome.outcome_date AS outcome_date')
              .joins <<~SQL
                INNER JOIN (
                  SELECT patient_program.patient_id,
                        MAX(patient_state.start_date) AS outcome_date
                  FROM patient_state
                  INNER JOIN patient_program
                    ON patient_program.patient_program_id = patient_state.patient_program_id
                    AND patient_program.voided = 0
                  INNER JOIN program
                    ON program.program_id = patient_program.program_id
                    AND program.name = 'HIV Program'
                    AND program.retired = 0
                  WHERE patient_state.voided = 0
                    AND patient_state.start_date < DATE(#{start_date}) + INTERVAL 1 DAY
                  GROUP BY patient_program.patient_id
                ) AS latest_outcome ON latest_outcome.patient_id = encounter.patient_id
              SQL
          end

          def age_group(end_date)
            select("disaggregated_age_group(person.birthdate, DATE(#{end_date})) AS age_group")
          end

          def guardian_visits(start_date, end_date)
            reception_encounter = EncounterType.find_by_name('HIV RECEPTION')

            select('IF(guardian.patient_id IS NOT NULL, "Yes", "No") AS guardian_visit')
              .joins <<~SQL
                LEFT JOIN (
                  SELECT guardian_enc.patient_id
                  FROM encounter guardian_enc
                  INNER JOIN obs present ON present.encounter_id = guardian_enc.encounter_id
                    AND present.voided = 0
                    AND present.concept_id = #{Concept.find_by_name('Responsible person present').concept_id}
                    AND present.value_coded = #{concept('Yes').concept_id}
                    AND guardian_enc.encounter_type = #{reception_encounter.encounter_type_id}
                    AND guardian_enc.voided = 0
                    AND guardian_enc.encounter_datetime >= '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
                    AND guardian_enc.encounter_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
                  INNER JOIN obs patient_absent ON patient_absent.encounter_id = guardian_enc.encounter_id
                    AND patient_absent.voided = 0
                    AND patient_absent.concept_id = #{Concept.find_by_name('Patient present for consultation').concept_id}
                    AND patient_absent.value_coded = #{concept('No').concept_id}
                  GROUP BY guardian_enc.patient_id
                )  AS guardian ON guardian.patient_id = patient.patient_id
              SQL
          end

          def missed_appointments(start_date, end_date)
            appointment_encounter = EncounterType.find_by_name('APPOINTMENT')
            treatment_encounter = EncounterType.find_by_name('TREATMENT')
            arv_drugs = Drug.arv_drugs.map(&:drug_id).join(',')

            select('IF (app_missed.patient_id IS NOT NULL, "Yes", "No") AS missed_appointment')
              .joins <<~SQL
                LEFT JOIN(
                  SELECT app.patient_id
                  FROM orders o
                  INNER JOIN encounter app ON app.patient_id = o.patient_id
                    AND app.encounter_type = #{appointment_encounter.encounter_type_id}
                    AND app.voided = 0
                    AND app.encounter_datetime >= '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
                    AND app.encounter_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
                  INNER JOIN obs app_date ON app_date.encounter_id = app.encounter_id
                    AND app_date.voided = 0
                    AND app_date.concept_id = #{concept('Appointment Date').concept_id}
                  LEFT JOIN encounter client_came ON client_came.patient_id = o.patient_id
                    AND client_came.voided = 0
                    AND client_came.encounter_type = #{treatment_encounter.encounter_type_id}#{' '}
                    AND client_came.encounter_datetime >= DATE(app.encounter_datetime) + INTERVAL 1 DAY#{' '}
                    AND client_came.encounter_datetime <= app_date.value_datetime
                  INNER JOIN drug_order d ON d.order_id = o.order_id
                    AND d.quantity > 0
                    AND d.drug_inventory_id IN(#{arv_drugs})
                  WHERE o.voided = 0
                  AND app_date.value_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
                  GROUP BY app.patient_id
                ) as app_missed ON app_missed.patient_id = patient.patient_id
              SQL
          end

          def ahd_lab_orders(start_date, end_date)
            test_types = [
              'HIV Viral load', 'CD4 count', 'CrAg', 'CSF CrAg',
              'Urine LAM', 'GeneXpert', 'FASH', 'Culture & Sensitivity',
              'TB Microscopic Exam'
            ]

            test_type_ids = test_types.map { |type| concept(type).concept_id }

            select('orders.test_results')
              .joins <<~SQL
                LEFT JOIN (
                    SELECT DISTINCT lab.patient_id,
                      GROUP_CONCAT(
                        CONCAT(
                          '"', tt.name, '":',
                          '"', CONCAT(result.value_modifier, "~",
                                COALESCE(result.value_numeric, result.value_text,
                                        result.value_coded)),
                          '"'
                        )
                      ) AS test_results
                      from orders
                              INNER JOIN encounter lab ON lab.patient_id = orders.patient_id
                          AND lab.encounter_datetime >= #{start_date}
                          AND lab.encounter_datetime <= #{end_date}
                          AND lab.voided = 0
                          AND orders.voided = 0
                              INNER JOIN obs test_type ON test_type.encounter_id = lab.encounter_id
                          AND test_type.concept_id = #{concept('Test type').concept_id}
                          AND test_type.value_coded IN (#{test_type_ids.join(', ')})
                              INNER JOIN concept_name tt ON tt.concept_id = test_type.value_coded
                              INNER JOIN obs tr ON tr.order_id = orders.order_id
                          AND tr.voided = 0
                          AND tr.concept_id = #{concept('Lab test result').concept_id}
                          AND tr.obs_group_id = test_type.obs_id
                              INNER JOIN obs result ON result.obs_group_id = tr.obs_id
                      GROUP BY lab.patient_id
                ) AS orders ON orders.patient_id = patient.patient_id
              SQL
          end

          def who_stage
            who_stage = concept('WHO stage').concept_id

            select('COALESCE(stage.value_coded, "Unknown") AS who_stage')
              .joins <<~SQL
                LEFT JOIN obs stage ON stage.person_id = encounter.patient_id
                AND stage.concept_id = #{who_stage}
                AND stage.voided = 0
              SQL
          end

          def ahd_classification
            classification = concept('AHD entry classification').concept_id

            select('COALESCE(class.value_text, "Unknown") AS classification')
              .joins <<~SQL
                LEFT JOIN obs class ON class.person_id = encounter.patient_id
                AND class.concept_id = #{classification}
                AND class.voided = 0
              SQL
          end

          def ever_received_arvs
            received = concept('Ever received ART?').concept_id
            merge(genders)
              .select('COALESCE(arv.value_coded, "No") AS arv, current.patient_id as current')
              .joins <<~SQL
                LEFT JOIN obs arv ON arv.person_id = encounter.patient_id
                AND arv.concept_id = #{received}
                AND arv.voided = 0
                LEFT JOIN temp_cohort_members current ON current.patient_id = encounter.patient_id
                AND current.date_enrolled <= encounter.encounter_datetime
              SQL
          end

          def started_cpt
            cpt_concept = concept('Cotrimoxazole').concept_id

            select("IF (on_cpt.patient_id IS NULL, 'No', 'Yes') AS started_cpt")
              .joins <<~SQL
                LEFT JOIN (
                  SELECT ods.patient_id
                  FROM orders ods
                  INNER JOIN drug_order dos ON ods.order_id = dos.order_id#{' '}
                    AND ods.voided = 0#{' '}
                    AND dos.quantity > 0#{' '}
                    AND ods.concept_id = #{cpt_concept}
                ) AS on_cpt ON on_cpt.patient_id = patient.patient_id
              SQL
          end

          def started_tpt
            select("IF (on_tpt.patient_id IS NULL, 'No', 'Yes') AS started_tpt")
              .joins <<~SQL
                LEFT JOIN (
                  SELECT oo.patient_id#{' '}
                  FROM orders oo
                  INNER JOIN drug_order do ON do.order_id = oo.order_id
                    AND do.quantity > 0
                    AND oo.order_type_id = (SELECT order_type_id FROM order_type WHERE name = 'Drug order' LIMIT 1)
                    AND oo.voided = 0
                  INNER JOIN concept_name AS tpt_drug_concepts
                    ON tpt_drug_concepts.concept_id = oo.concept_id
                    AND tpt_drug_concepts.name IN ('Rifapentine', 'Isoniazid', 'Isoniazid/Rifapentine')
                    AND tpt_drug_concepts.voided = 0
                  INNER JOIN encounter tr
                    ON tr.encounter_id = oo.encounter_id
                    AND tr.encounter_type = (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment' LIMIT 1)
                    AND tr.voided = 0
                ) AS on_tpt ON on_tpt.patient_id = patient.patient_id
              SQL
          end

          def patients_on_tb_treatment(patient_ids)
            on_tb_treatment = concept('TB Treatment').concept_id
            tb_status = concept('TB Status').concept_id
            no = concept('No').concept_id
            on_tb_treatment_concept_ids = ConceptName.where(name: 'RX').collect(&:concept_id)

            ActiveRecord::Base.connection.execute <<~SQL
              SELECT o.person_id patient_id
              FROM (
                SELECT person_id, MAX(obs_datetime) AS obs_datetime
                FROM obs o
                JOIN encounter e ON o.encounter_id = e.encounter_id
                WHERE o.person_id IN (#{patient_ids.join(', ')})
                  AND o.voided = 0
                  AND o.concept_id = #{tb_status}
                  AND o.value_coded IN (#{on_tb_treatment_concept_ids.join(', ')})
              ) tb_status_max
              JOIN obs o ON o.obs_datetime = tb_status_max.obs_datetime
              JOIN encounter e ON o.encounter_id = e.encounter_id
              WHERE o.person_id = tb_status_max.person_id
                AND o.concept_id = #{tb_status}
                AND NOT EXISTS (
                  SELECT 1
                  FROM obs o2
                  WHERE o2.person_id = tb_status_max.person_id
                    AND o2.concept_id = #{on_tb_treatment}
                    AND o2.value_coded = #{no}
                    AND o2.obs_datetime >= tb_status_max.obs_datetime
                )
              ORDER BY o.obs_datetime DESC
              LIMIT 1#{'            '}
            SQL
          end

          def ahd_symptoms
            symptoms = concept('AHD Symptom').concept_id
            yes = concept('Yes').concept_id

            select('GROUP_CONCAT(DISTINCT symptom_name.name) AS symptoms')
              .joins <<~SQL
                LEFT JOIN obs symptom_obs ON obs.person_id = encounter.patient_id
                AND symptom_obs.concept_id = #{symptoms}
                AND symptom_obs.voided = 0
                INNER JOIN obs symptom ON symptom.obs_group_id = symptom_obs.obs_id
                AND symptom.value_coded = #{yes}
                AND symptom.voided = 0
                INNER JOIN concept_name symptom_name ON symptom_name.concept_id = symptom_obs.value_coded
                AND symptom_name.voided = 0
              SQL
          end

          def female_breastfeeding
            breastfeeding = ConceptName.where(name: ['Breast feeding?', 'Breast feeding', 'Breastfeeding'])
                                       .pluck(:concept_id)&.join(',')
            yes = concept('Yes').concept_id

            joins(:person)
              .select('COALESCE(bf.value_coded, "No") AS bf')
              .joins <<~SQL
                LEFT JOIN obs bf ON bf.person_id = encounter.patient_id
                AND bf.concept_id IN (#{breastfeeding})
                AND bf.value_coded = #{yes}
                AND bf.voided = 0
              SQL
          end

          def female_pregnant
            pregnant = ConceptName.where(name: ['Is patient pregnant?', 'patient pregnant'])
                                  .pluck(:concept_id)&.join(',')
            yes = concept('Yes').concept_id

            joins(:person)
              .select('COALESCE(preg.value_coded, "No") AS preg')
              .joins <<~SQL
                LEFT JOIN obs preg ON preg.person_id = encounter.patient_id
                AND preg.concept_id IN (#{pregnant})
                AND preg.value_coded = #{yes}
                AND preg.voided = 0
              SQL
          end
        end
      end
    end
  end
end
