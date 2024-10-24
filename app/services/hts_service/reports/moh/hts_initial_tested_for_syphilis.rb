# frozen_string_literal: true

module HtsService
  module Reports
    module Moh
      # HTS Initial tested for syphilis
      class HtsInitialTestedForSyphilis
        include HtsService::Reports::HtsReportBuilder
        attr_accessor :start_date, :end_date

        YES_ANSWER = 'Yes'
        NO_ANSWER = 'No'
        TESTING_ENCOUNTER = EncounterType.find_by_name('HIV Testing').encounter_type_id
        HEP_B_TEST_RESULT = 'Hepatitis B Test Result'
        SYPHILIS_TEST_RESULT = 'Syphilis Test Result'
        PREGNANCY_STATUS = 'Pregnancy status'
        CIRCUMCISION_STATUS = 'Circumcision status'
        MALE_CONDOMS = 'Male Condoms'
        FEMALE_CONDOMS = 'Female Condoms'
        FRS = 'HTS Referal Slips Recipients'
        REFERRAL_FOR_RETESTING = 'Referral for Re-Testing'
        TIME_OF_HIV_TEST = 'Time of HIV test'
        TIME_SINCE_LAST_MEDICATION = 'Time since last taken medication'
        PREVIOUS_HIV_TEST = 'Previous HIV Test Results'
        PREVIOUS_HIV_TEST_DONE = 'Previous HIV Test done'
        RISK_CATEGORY = 'client risk category'
        PARTNER_PRESENT = 'Partner Present'
        PARTNER_HIV_STATUS = 'Partner HIV Status'
        TAKEN_ARVS_BEFORE = 'Taken ARV before'
        TAKEN_PREP_BEFORE = 'Taken PrEP before'
        TAKEN_PEP_BEFORE = 'Taken PEP before'
        REFERALS_ORDERED = 'Referrals ordered'
        TEST_ONE = 'Test 1'
        TEST_TWO = 'Test 2'
        TEST_THREE = 'Test 3'
        PREGNANT_WOMAN = 'Pregnant woman'
        NOT_PREGNANT = 'Not Pregnant / Breastfeeding'
        BREASTFEEDING = 'Breastfeeding'
        LINKED_CONCEPT = 'Linked'
        HIV_STATUS = 'HIV status'
        HTS_ACCESS_TYPE = 'HTS Access Type'
        LOCATION_WHERE_TEST_TOOK_PLACE = 'Location where test took place'

        INDICATORS = [
          { name: 'hiv_status', concept: HIV_STATUS, value: 'value_coded', join: 'LEFT' },
          { name: 'access_type', concept: HTS_ACCESS_TYPE, value: 'value_coded', join: 'LEFT' },
          { name: 'test_location', concept: LOCATION_WHERE_TEST_TOOK_PLACE, value: 'value_text', join: 'LEFT' },
          { name: 'hep_b_test_result', concept: HEP_B_TEST_RESULT, value: 'value_coded', join: 'INNER' },
          { name: 'syphilis_test_result', concept: SYPHILIS_TEST_RESULT, value: 'value_coded', join: 'LEFT' },
          { name: 'test_one', concept: TEST_ONE, join: 'LEFT' },
          { name: 'test_two', concept: TEST_TWO, join: 'LEFT' },
          { name: 'test_three', concept: TEST_THREE, join: 'LEFT' },
          { name: 'pregnancy_status', concept: PREGNANCY_STATUS, value: 'value_coded', join: 'LEFT' },
          { name: 'circumcision_status', concept: CIRCUMCISION_STATUS, value: 'value_coded', join: 'LEFT' },
          { name: 'male_condoms', concept: MALE_CONDOMS, join: 'LEFT', value: 'value_numeric' },
          { name: 'female_condoms', concept: FEMALE_CONDOMS, join: 'LEFT', value: 'value_numeric' },
          { name: 'frs', concept: FRS, join: 'LEFT', value: 'value_numeric' },
          { name: 'referal_for_retesting', concept: REFERRAL_FOR_RETESTING, join: 'LEFT' },
          { name: 'time_of_hiv_test', concept: TIME_OF_HIV_TEST, value: 'value_datetime', join: 'LEFT' },
          { name: 'time_since_last_medication', value: 'value_datetime', concept: TIME_SINCE_LAST_MEDICATION,
            join: 'LEFT' },
          { name: 'previous_hiv_test', concept: PREVIOUS_HIV_TEST, join: 'LEFT' },
          { name: 'previous_hiv_test_done', concept: PREVIOUS_HIV_TEST_DONE, join: 'LEFT' },
          { name: 'risk_category', concept: RISK_CATEGORY, join: 'LEFT' },
          { name: 'partner_present', concept: PARTNER_PRESENT, value: 'value_text', join: 'LEFT' },
          { name: 'partner_hiv_status', concept: PARTNER_HIV_STATUS, join: 'LEFT' },
          { name: 'taken_arvs_before', concept: TAKEN_ARVS_BEFORE, join: 'LEFT' },
          { name: 'taken_prep_before', concept: TAKEN_PREP_BEFORE, join: 'LEFT' },
          { name: 'taken_pep_before', concept: TAKEN_PEP_BEFORE, join: 'LEFT' },
          { name: 'referrals_ordered', concept: REFERALS_ORDERED, value: 'value_text', join: 'LEFT' }
          # {
          #   name: 'outcome',
          #   concept: 'Antiretroviral status or outcome',
          #   value: 'value_coded',
          #   join: 'LEFT',
          #   max: true
          # }
        ].freeze

        def initialize(start_date:, end_date:)
          @start_date = start_date&.to_date&.beginning_of_day
          @end_date = end_date&.to_date&.end_of_day
          @data = {
            'missing_link_id_not_in_conf_register' => [], 'linking_with_hiv_confirmatory_register_missing_linkid_not_in_conf_register' => [],
            'hiv_test_1_result_missing' => [], 'linking_with_hiv_confirmatory_register_total_clients_hiv_test_1_negative' => [],
            'hepatitis_b_test_result_not_done' => [], 'linking_with_hiv_confirmatory_register_invalid_linkid_in_conf_register' => [],
            'hepatitis_b_test_result_missing' => [], 'linking_with_hiv_confirmatory_register_total_clients_hiv_test_1_not_done' => [],
            'syphilis_test_result_not_done' => [],
            'hiv_test_1_result_not_done' => [],
            'risk_category_missing' => [],
            'age_group_years_missing' => [],
            'access_point_type_invalid_entry' => [],
            'access_point_type_missing' => [],
            'sex_or_pregnancy_invalid_entry' => [],
            'sex_or_pregnancy_missing' => [],
            'last_hiv_test_invalid_self_test' => [],
            'last_hiv_test_invalid_entry' => [],
            'last_hiv_test_missing' => [],
            'time_since_last_hiv_test_invalid_entry' => [],
            'time_since_last_hiv_test_not_applicable_or_missing' => [],
            'ever_taken_arvs_invalid_entry' => [],
            'ever_taken_arvs_missing' => [],
            'time_since_last_taken_arvs_invalid_entry' => [],
            'time_since_last_taken_arvs_not_applicable_or_missing' => [],
            'risk_category_invalid_entry' => [],
            'hiv_test_1_result_invalid_entry' => [],
            'hepatitis_b_test_result_invalid_entry' => [],
            'syphilis_test_result_invalid_entry' => [],
            'syphilis_test_result_missing' => [],
            'partner_present_invalid_entry' => [],
            'partner_present_missing' => [],
            'partner_hiv_status_invalid_entry' => [],
            'partner_hiv_status_missing' => [],
            'referral_for_hiv_retesting_invalid_entry' => [],
            'referral_for_hiv_retesting_missing' => [],
            'referral_invalid_entry' => [],
            'referral_missing' => [],
            'frs_given_family_referral_slips_sum' => [],
            'frs_given_invalid_entry' => [],
            'male_condoms_given_male_condoms_sum' => [],
            'male_condoms_given_invalid_entry' => [],
            'female_condoms_given_invalid_entry' => [],
            'not_applicable_not_linked' => [],
            'invalid_link_id_in_conf_register' => [],
            'linking_with_hiv_confirmatory_register_linked' => [],
            'linking_with_hiv_confirmatory_register_not_applicable_not_linked' => []
          }
        end

        def data
          init_report
          fetch_hepatitis_b_clients
          fetch_hiv_tests
          fetch_partner_status
          fetch_referral_retests
          # linked_clients
          fetch_risk_category
          fetch_referrals
          fetch_ever_taken_drugs_before
          fetch_items_given
          set_unique
        end

        private

        def init_report
          @query = ObsValueScopeRevised.call(his_patients_rev, INDICATORS)
          @query = @query.select { |q| !q['syphilis_test_result'].nil? || !q['syphilis_test_result'].blank? }
        end

        def set_unique
          @data.each do |key, obj|
            if %w[frs_given_family_referral_slips_sum male_condoms_given_male_condoms_sum
                  female_condoms_given_female_condoms_sum].include?(key)
              @data[key] = obj
              next
            end
            @data[key] = obj&.map { |q| q['person_id'] }&.uniq
          end
        end

        def filter_hash(key, value)
          return @query.select { |q| q[key[0]] == value && q[key[1]] == value } if key.is_a?(Array)

          @query.select { |q| q[key]&.to_s&.strip&.downcase == value&.to_s&.strip&.downcase }
        end

        def get_diff(obs_time, time_since)
          (obs_time&.to_date&.- time_since&.to_date).to_i
        rescue StandardError
          -1
        end

        def birthdate_to_age(birthdate)
          today = Date.today
          today.year - birthdate.year
        end

        def fetch_hepatitis_b_clients
          @data['total_clients_tested_for_syphilis'] = @query
          @data['access_point_type_total_clients_tested_at_the_facility'] =
            filter_hash('access_type', concept('Health facility').concept_id)
          @data['access_point_type_total_clients_tested_in_the_community'] =
            filter_hash('access_type', concept('Community').concept_id)
          @data['access_point_type_facility_vct'] = filter_hash('access_type', concept('Health facility').concept_id).select do |q|
            q['test_location'] == 'VCT'
          end
          @data['access_point_type_facility_anc_first_visit'] = filter_hash('access_type', concept('Health facility').concept_id).select do |q|
            q['test_location']&.downcase == 'anc first visit'
          end
          @data['access_point_type_facility_inpatient'] = filter_hash('access_type', concept('Health facility').concept_id).select do |q|
            q['test_location'] == 'Inpatient'
          end
          @data['access_point_type_facility_sti'] = filter_hash('access_type', concept('Health facility').concept_id).select do |q|
            q['test_location'] == 'STI'
          end
          @data['access_point_type_facility_pmtctfup'] = filter_hash('access_type', concept('Health facility').concept_id).select do |q|
            q['test_location'] == 'PMTCT FUP'
          end
          @data['access_point_type_facility_index'] = filter_hash('access_type', concept('Health facility').concept_id).select do |q|
            q['test_location'] == 'Index'
          end
          @data['access_point_type_facility_paediatric'] = filter_hash('access_type', concept('Health facility').concept_id).select do |q|
            q['test_location'] == 'Paediatric'
          end
          @data['access_point_type_facility_malnutrition'] = filter_hash('access_type', concept('Health facility').concept_id).select do |q|
            q['test_location'] == 'Malnutrition'
          end
          @data['access_point_type_facility_vmmc'] = filter_hash('access_type', concept('Health facility').concept_id).select do |q|
            q['test_location'] == 'VMMC'
          end
          @data['access_point_type_facility_tb'] = filter_hash('access_type', concept('Health facility').concept_id).select do |q|
            q['test_location'] == 'TB'
          end
          @data['access_point_type_facility_opd'] = filter_hash('access_type', concept('Health facility').concept_id).select do |q|
            q['test_location'] == 'OPD'
          end
          @data['access_point_type_facility_other_pitc'] = filter_hash('access_type', concept('Health facility').concept_id).select do |q|
            q['test_location'] == 'Other'
          end
          @data['access_point_type_facility_sns'] = filter_hash('access_type', concept('Health facility').concept_id).select do |q|
            q['test_location'] == 'SNS'
          end
          @data['access_point_type_community_vmmc'] = filter_hash('access_type', concept('Community').concept_id).select do |q|
            q['test_location'] == 'VMMC'
          end
          @data['access_point_type_community_index'] = filter_hash('access_type', concept('Community').concept_id).select do |q|
            q['test_location'] == 'Index'
          end
          @data['access_point_type_community_mobile'] = filter_hash('access_type', concept('Community').concept_id).select do |q|
            q['test_location'] == 'Mobile'
          end
          @data['access_point_type_community_vct'] = filter_hash('access_type', concept('Community').concept_id).select do |q|
            q['test_location'] == 'VCT'
          end
          @data['access_point_type_community_other'] = filter_hash('access_type', concept('Community').concept_id).select do |q|
            q['test_location'] == 'Other'
          end
          @data['access_point_type_community_sns'] = filter_hash('access_type', concept('Community').concept_id).select do |q|
            q['test_location'] == 'SNS'
          end

          @data['sex_or_pregnancy_total_males'] = filter_hash('gender', 'M')
          @data['sex_or_pregnancy_male_circumcised'] =
            filter_hash('circumcision_status', concept(YES_ANSWER).concept_id)
          @data['sex_or_pregnancy_male_noncircumcised'] =
            filter_hash('circumcision_status', concept(NO_ANSWER).concept_id)

          @data['age_group_years_a_under_1'] = @query.select { |q| birthdate_to_age(q['birthdate']) < 1 }
          @data['age_group_years_b_114'] = @query.select { |q| (1..14).include?(birthdate_to_age(q['birthdate'])) }
          @data['age_group_years_c_1524'] = @query.select { |q| (15..24).include?(birthdate_to_age(q['birthdate'])) }
          @data['age_group_years_d_25plus'] = (@query.select { |q| birthdate_to_age(q['birthdate']) >= 25 })

          @data['sex_or_pregnancy_total_females'] = filter_hash('gender', 'F')
          @data['sex_or_pregnancy_female_pregnant'] =
            filter_hash('pregnancy_status', concept(PREGNANT_WOMAN).concept_id)
          @data['sex_or_pregnancy_female_nonpregnant'] =
            filter_hash('pregnancy_status', concept(NOT_PREGNANT).concept_id)
          @data['sex_or_pregnancy_female_breastfeeding'] =
            filter_hash('pregnancy_status', concept(BREASTFEEDING).concept_id)

          @data['hiv_test_1_result_negative'] = filter_hash('test_one', concept('Negative').concept_id)
          @data['total_clients_hiv_test_1_negative'] = filter_hash('test_one', concept('Negative').concept_id)
          @data['hiv_test_1_result_positive'] = filter_hash('test_one', concept('Positive').concept_id)
          @data['linking_with_hiv_confirmatory_register_total_clients_hiv_test_1_positive'] =
            filter_hash('test_one', concept('Positive').concept_id)

          @data['hepatitis_b_test_result_negative'] = filter_hash('hep_b_test_result', concept('Negative').concept_id)
          @data['hepatitis_b_test_result_positive'] = filter_hash('hep_b_test_result', concept('Positive').concept_id)
          @data['hepatitis_b_test_result_missing'] = filter_hash('hep_b_test_result', nil)

          @data['syphilis_test_result_negative'] = filter_hash('syphilis_test_result', concept('Negative').concept_id)
          @data['syphilis_test_result_positive'] = filter_hash('syphilis_test_result', concept('Positive').concept_id)
        end

        def fetch_hiv_tests
          @data['last_hiv_test_never_tested'] = filter_hash('previous_hiv_test', concept('Never Tested').concept_id)
          @data['last_hiv_test_negative_selftest'] = filter_hash('previous_hiv_test_done', concept('Self').concept_id).select do |q|
            q['previous_hiv_test'] == concept('Negative').concept_id
          end
          @data['last_hiv_test_negative_prof_test'] = filter_hash('previous_hiv_test_done', concept('Professional').concept_id).select do |q|
            q['previous_hiv_test'] == concept('Negative').concept_id
          end
          @data['last_hiv_test_positive_selftest'] = filter_hash('previous_hiv_test_done', concept('Self').concept_id).select do |q|
            [concept('Positive').concept_id, concept('Positive NOT on ART').concept_id, concept('Positive on ART').concept_id].include?(q['previous_hiv_test'])
          end
          @data['last_hiv_test_positive_prof_test'] = filter_hash('previous_hiv_test_done', concept('Professional').concept_id).select do |q|
            [concept('Positive').concept_id, concept('Positive NOT on ART').concept_id, concept('Positive on ART').concept_id].include?(q['previous_hiv_test'])
          end
          @data['last_hiv_test_positive_prof_initial_test'] = filter_hash('previous_hiv_test_done', concept('Initial professional').concept_id).select do |q|
            [concept('Positive').concept_id, concept('Positive NOT on ART').concept_id, concept('Positive on ART').concept_id].include?(q['previous_hiv_test'])
          end
          @data['last_hiv_test_inconclusive_prof_test'] = filter_hash('previous_hiv_test_done', concept('Professional').concept_id).select do |q|
            q['previous_hiv_test'] == concept('Invalid or inconclusive').concept_id
          end
          @data['last_hiv_test_invalid_selftest'] = filter_hash('previous_hiv_test_done', concept('Self').concept_id).select do |q|
            q['previous_hiv_test'] == concept('Invalid or inconclusive').concept_id
          end
          @data['last_hiv_test_exposed_infant'] = filter_hash('previous_hiv_test', concept('Exposed infant').concept_id)

          @data['time_since_last_hiv_test_same_day'] = @query.select do |q|
            get_diff(q['encounter_datetime'], q['time_of_hiv_test']).zero?
          end
          @data['time_since_last_hiv_test_1_to_13_days'] = @query.select do |q|
            (1..13).include?(get_diff(q['encounter_datetime'], q['time_of_hiv_test']))
          end
          @data['time_since_last_hiv_test_35_months'] = @query.select do |q|
            (61..150).include?(get_diff(q['encounter_datetime'], q['time_of_hiv_test']))
          end
          @data['time_since_last_hiv_test_611_months'] = @query.select do |q|
            (151..330).include?(get_diff(q['encounter_datetime'], q['time_of_hiv_test']))
          end
          @data['time_since_last_hiv_test_14_days_to_2_months'] = @query.select do |q|
            (14..60).include?(get_diff(q['encounter_datetime'], q['time_of_hiv_test']))
          end
          @data['time_since_last_hiv_test_12plus_months'] = @query.select do |q|
            get_diff(q['encounter_datetime'], q['time_of_hiv_test']) > 365
          end
          @data['time_since_last_hiv_test_not_applicable_or_missing'] = @data['last_hiv_test_never_tested']
          @data['time_since_last_hiv_test_not_applicable_or_missing'] += filter_hash('time_of_hiv_test', nil)
          @data['time_since_last_hiv_test_not_applicable_or_missing'] += @query.select do |q|
            get_diff(q['encounter_datetime'], q['time_of_hiv_test']).negative?
          end
        end

        def fetch_risk_category
          @data['risk_category_low'] = filter_hash('risk_category', concept('Low risk').concept_id)
          @data['risk_category_ongoing'] = filter_hash('risk_category', concept('On-going risk').concept_id)
          @data['risk_category_highrisk_event'] =
            filter_hash('risk_category', concept('High risk event in last 3 months').concept_id)
          @data['risk_category_not_done'] = filter_hash('risk_category', concept('Risk assessment not done').concept_id)
        end

        def fetch_items_given
          @data['male_condoms_given_male_condoms_sum'] = @query.map { |q| q['male_condoms'] }.compact.sum
          @data['female_condoms_given_female_condoms_sum'] = @query.map { |q| q['female_condoms'] }.compact.sum
          @data['frs_given_family_referral_slips_sum'] = @query.map { |q| q['frs'] }.compact.sum
        end

        def fetch_ever_taken_drugs_before
          @data['ever_taken_arvs_no'] = @query.select do |r|
            [r['taken_prep_before'], r['taken_pep_before'], r['taken_arvs_before']].all? do |q|
              q == concept(NO_ANSWER).concept_id
            end
          end
          @data['ever_taken_arvs_prep'] = filter_hash('taken_prep_before', concept(YES_ANSWER).concept_id)
          @data['ever_taken_arvs_pep'] = filter_hash('taken_pep_before', concept(YES_ANSWER).concept_id)
          @data['ever_taken_arvs_art'] = filter_hash('taken_arvs_before', concept(YES_ANSWER).concept_id)
          @data['time_since_last_taken_arvs_same_day'] = @query.select do |q|
            get_diff(q['encounter_datetime'], q['time_since_last_medication']).zero?
          end
          @data['time_since_last_taken_arvs_1_to_13_days'] = @query.select do |q|
            (1..13).include?(get_diff(q['encounter_datetime'], q['time_since_last_medication']))
          end
          @data['time_since_last_taken_arvs_14_days_to_2_months'] = @query.select do |q|
            (14..60).include?(get_diff(q['encounter_datetime'], q['time_since_last_medication']))
          end
          @data['time_since_last_taken_arvs_35_months'] = @query.select do |q|
            (61..150).include?(get_diff(q['encounter_datetime'], q['time_since_last_medication']))
          end
          @data['time_since_last_taken_arvs_611_months'] = @query.select do |q|
            (151..330).include?(get_diff(q['encounter_datetime'], q['time_since_last_medication']))
          end
          @data['time_since_last_taken_arvs_12plus_months'] = @query.select do |q|
            get_diff(q['encounter_datetime'], q['time_since_last_medication']) >= 365
          end
          @data['time_since_last_taken_arvs_not_applicable_or_missing'] = @data['ever_taken_arvs_no']
        end

        def fetch_partner_status
          @data['partner_present_yes'] = filter_hash('partner_present', 'Yes')
          @data['partner_present_no'] = filter_hash('partner_present', 'No')
          @data['partner_present_missing'] = filter_hash('partner_present', nil)

          @data['partner_hiv_status_no_partner'] = filter_hash('partner_hiv_status', concept('No partner').concept_id)
          @data['partner_hiv_status_hiv_status_unknown'] =
            filter_hash('partner_hiv_status', concept('HIV unknown').concept_id)
          @data['partner_hiv_status_hiv_negative'] = filter_hash('partner_hiv_status', concept('Negative').concept_id)
          @data['partner_hiv_status_hiv_positive_art_unknown'] =
            filter_hash('partner_hiv_status', concept('Positive ART unknown').concept_id)
          @data['partner_hiv_status_hiv_positive_not_on_art'] =
            filter_hash('partner_hiv_status', concept('Positive NOT on ART').concept_id)
          @data['partner_hiv_status_hiv_positive_on_art'] =
            filter_hash('partner_hiv_status', concept('Positive on ART').concept_id)
          @data['partner_hiv_status_missing'] = filter_hash('partner_hiv_status', nil)
        end

        def fetch_referral_retests
          @data['referral_for_hiv_retesting_no_retest_needed'] =
            filter_hash('referal_for_retesting', concept('NOT done').concept_id)
          @data['referral_for_hiv_retesting_retest_needed'] =
            filter_hash('referal_for_retesting', 10_616) # TODO: Fix this voided concept
          @data['referral_for_hiv_retesting_confirmatory_test'] =
            filter_hash('referal_for_retesting', concept('Confirmatory HIV test').concept_id)
          @data['referral_for_hiv_retesting_missing'] =
            filter_hash('referal_for_retesting', nil)
        end

        def fetch_referrals
          @data['referral_for_vmmc'] = filter_hash('referrals_ordered', 'VMMC')
          @data['referral_for_prep'] = filter_hash('referrals_ordered', 'PrEP')
          @data['referral_for_sti'] = filter_hash('referrals_ordered', 'STI')
          @data['referral_for_tb'] = filter_hash('referrals_ordered', 'TB')
          @data['referral_for_pep'] = filter_hash('referrals_ordered', 'PEP')
        end

        def linked_clients
          not_linked_concepts = [concept('Refused').concept_id, concept('Died').concept_id,
                                 concept('Unknown').concept_id]

          @data['linking_with_hiv_confirmatory_register_linked'] = filter_hash('outcome', concept('Linked').concept_id)
          @data['linking_with_hiv_confirmatory_register_not_applicable_not_linked'] = @query.select do |q|
            q['outcome'].nil? || not_linked_concepts.include?(q['outcome'])
          end
        end
      end
    end
  end
end
