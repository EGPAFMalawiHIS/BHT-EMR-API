# frozen_string_literal: true

module ArtService
  module Reports
    module Pepfar
      ##
      # Common utilities for Pepfar reports
      module Utils
        ##
        # An array of all groups as required by Pepfar.
        def pepfar_age_groups
          @pepfar_age_groups ||= [
            'Unknown',
            '<1 year',
            '1-4 years', '5-9 years',
            '10-14 years', '15-19 years',
            '20-24 years',
            '25-29 years', '30-34 years',
            '35-39 years', '40-44 years',
            '45-49 years', '50-54 years',
            '55-59 years', '60-64 years',
            '65-69 years', '70-74 years',
            '75-79 years', '80-84 years',
            '85-89 years',
            '90 plus years'
          ].freeze
        end

        COHORT_REGIMENS = %w[
          0P 2P 4PP 4PA 9PP 9PA 11PP 11PA 12PP 12PA 14PP 14PA 15PP 15PA 16P 17PP 17PA
          4A 5A 6A 7A 8A 9A 10A 11A 12A 13A 14A 15A 16A 17A
        ].freeze

        ##
        # Returns the drilldown information for all specified patients (ie patient_ids)
        #
        # Information returned for a patient is as follows:
        #   * patient_id
        #   * arv_number or filing_number
        #   * age_group
        #   * birthdate
        #   * gender
        def pepfar_patient_drilldown_information(patients, current_date)
          raise ArgumentError, "current_date can't be nil" unless current_date

          Person.joins("LEFT JOIN patient_identifier ON patient_identifier.patient_id = person.person_id
                          AND patient_identifier.voided = 0
                          AND patient_identifier.identifier_type IN (#{pepfar_patient_identifier_type.to_sql})")
                .where(person_id: patients)
                .select("person.person_id AS patient_id,
                         person.gender,
                         person.birthdate,
                         disaggregated_age_group(person.birthdate, DATE(#{ActiveRecord::Base.connection.quote(current_date)})) AS age_group,
                         patient_identifier.identifier AS arv_number")
        end

        ##
        # Returns the preferred Pepfar identifier type.
        #
        # In some clinics like Lighthouse Filing numbers are used exclusively and in other
        # sites, ARV Numbers are used.
        def pepfar_patient_identifier_type
          name = GlobalPropertyService.use_filing_numbers? ? 'Filing number' : 'ARV Number'
          PatientIdentifierType.where(name:).select(:patient_identifier_type_id)
        end

        FULL_6H_COURSE_PILLS = 146
        FULL_3HP_COURSE_DAYS = 12.days
        # NOTE: Arrived at 12 days above from how 3HP is prescribed. 1st time prescription
        #       A patient takes 3HP once every week. Therefore it is 4 times a months
        #       Multiply that with 3 months we arrive at 12
        #       Hence the patient is taking this drug 12 times to be considered complete on
        #       3HP

        ##
        # Returns whether a patient completed their course of TPT
        def patient_completed_tpt?(patient, tpt)
          if tpt == '3HP'
            # return true if patient['total_days_on_medication'].to_i >= 83 # 3 months
            return true if patient['months_on_tpt'].to_i >= 3

            divider = patient['drug_concepts'].split(',').length > 1 ? 14.0 : 7.0
            days_on_medication = (patient['total_days_on_medication'] / divider).round
            days_on_medication.days >= FULL_3HP_COURSE_DAYS
          else
            patient['total_days_on_medication'].to_i >= FULL_6H_COURSE_PILLS
          end
        end

        # this just gives all clients who are truly external or drug refill
        # rubocop:disable Metrics/MethodLength
        # rubocop:disable Metrics/AbcSize
        def drug_refills_and_external_consultation_list
          to_remove = [0]

          type_of_patient_concept = ConceptName.find_by_name('Type of patient').concept_id
          new_patient_concept = ConceptName.find_by_name('New patient').concept_id
          drug_refill_concept = ConceptName.find_by_name('Drug refill').concept_id
          external_concept = ConceptName.find_by_name('External Consultation').concept_id
          hiv_clinic_registration_id = EncounterType.find_by_name('HIV CLINIC REGISTRATION').encounter_type_id

          ActiveRecord::Base.connection.select_all("
            SELECT p.person_id patient_id
            FROM person p
            INNER JOIN patient_program pp ON pp.patient_id = p.person_id AND pp.program_id = #{Program.find_by_name('HIV Program').id} AND pp.voided = 0
            INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id AND ps.state = 7 AND ps.start_date IS NOT NULL
            LEFT JOIN encounter as hiv_registration ON hiv_registration.patient_id = p.person_id AND hiv_registration.encounter_datetime < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) AND hiv_registration.encounter_type = #{hiv_clinic_registration_id} AND hiv_registration.voided = 0
            LEFT JOIN (SELECT * FROM obs WHERE concept_id = #{type_of_patient_concept} AND voided = 0 AND value_coded = #{new_patient_concept} AND obs_datetime < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY) AS new_patient ON p.person_id = new_patient.person_id
            LEFT JOIN (SELECT * FROM obs WHERE concept_id = #{type_of_patient_concept} AND voided = 0 AND value_coded = #{drug_refill_concept} AND obs_datetime < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY) AS refill ON p.person_id = refill.person_id
            LEFT JOIN (SELECT * FROM obs WHERE concept_id = #{type_of_patient_concept} AND voided = 0 AND value_coded = #{external_concept} AND obs_datetime < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY) AS external ON p.person_id = external.person_id
            WHERE (refill.value_coded IS NOT NULL OR external.value_coded IS NOT NULL)
            AND NOT (hiv_registration.encounter_id IS NOT NULL OR new_patient.value_coded IS NOT NULL)
            GROUP BY p.person_id
            ORDER BY hiv_registration.encounter_datetime DESC, refill.obs_datetime DESC, external.obs_datetime DESC;").each do |record|
            to_remove << record['patient_id'].to_i
          end
          to_remove.join(',')
        end
        # rubocop:enable Metrics/MethodLength
        # rubocop:enable Metrics/AbcSize

        def rifapentine_concept
          @rifapentine_concept ||= ConceptName.find_by!(name: 'Rifapentine')
        end

        def isoniazid_rifapentine_concept
          @isoniazid_rifapentine_concept ||= ConceptName.find_by!(name: 'Isoniazid/Rifapentine')
        end

        def patient_on_3hp?(patient)
          drug_concepts = patient['drug_concepts'].split(',').collect(&:to_i)
          (drug_concepts & [rifapentine_concept.concept_id, isoniazid_rifapentine_concept&.concept_id]).any?
        end

        def patient_on_tb_treatment?(patient_id)
          Observation.where(person_id: patient_id, concept_id: ConceptName.find_by_name('TB status').concept_id,
                            value_coded: ConceptName.find_by_name('Confirmed TB on treatment').concept_id)
                     .where("obs_datetime < DATE(#{end_date}) + INTERVAL 1 DAY").exists?
        end
      end
    end
  end
end
