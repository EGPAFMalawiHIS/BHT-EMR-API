module HtsService
  module Reports
    module HtsReportBuilder

      def hts_age_groups
        [
          { less_than_one: "<1 year" },
          { one_to_four: "1-4 years" },
          { five_to_nine: "5-9 years" },
          { ten_to_fourteen: "10-14 years" },
          { fifteen_to_nineteen: "15-19 years" },
          { twenty_to_twenty_four: "20-24 years" },
          { twenty_five_to_twenty_nine: "25-29 years" },
          { thirty_to_thirty_four: "30-34 years" },
          { thirty_five_to_thirty_nine: "35-39 years" },
          { fourty_to_fourty_four: "40-44 years" },
          { fourty_five_to_fourty_nine: "45-49 years" },
          { fifty_to_fifty_four: "50-54 years" },
          { fifty_five_to_fifty_nine: "55-59 years" },
          { sixty_to_sixty_four: "60-64 years" },
          { sixty_five_to_sixty_nine: "65-69 years" },
          { seventy_to_seventy_four: "70-74 years" },
          { seventy_five_to_seventy_nine: "75-79 years" },
          { eighty_to_eighty_four: "80-84 years" },
          { eighty_five_to_eighty_nine: "85-89 years" },
          { ninety_plus: "90 plus years" },
        ].freeze
      end

      def his_patients_rev
        Patient.joins(:person, encounters: :program)
               .where(
            encounter: {
              encounter_datetime: @start_date..@end_date,
              encounter_type: EncounterType.find_by_name("Testing"),
            },
            program: { program_id: Program.find_by_name("HTC PROGRAM").id },
          )
      end

      def self_test_clients
        Patient.joins(:person, encounters: [:observations, :program])
               .merge(
            Patient.joins(<<-SQL)
          INNER JOIN encounter test ON test.voided = 0 AND test.patient_id = patient.patient_id
          INNER JOIN obs visit ON visit.voided = 0 AND visit.person_id = person.person_id
          SQL
          )
          .where(
            visit: { concept_id: concept("Visit type").concept_id, value_coded: concept("Self test distribution").concept_id },
            encounter: {
              encounter_datetime: @start_date..@end_date,
              encounter_type: EncounterType.find_by_name("ITEMS GIVEN"),
            },
            program: { program_id: Program.find_by_name("HTC PROGRAM").id },
          )
      end
    end
  end
end

class ObsValueScope
  # QUERY_STRING =
  #   "%<join>s JOIN (
  #         SELECT %<value>s, person_id
  #         FROM obs
  #         WHERE obs.voided = 0 AND obs.concept_id = %<concept_id>s
  #       ) AS %<name>s ON %<name>s.person_id = person.person_id
  #     ".freeze

  QUERY_STRING =
    <<~SQL
      %<join>s JOIN obs %<name>s ON %<name>s.person_id = person.person_id
      AND %<name>s.voided = 0
      AND %<name>s.concept_id = %<concept_id>s
    SQL
    .freeze

  def self.call(model:, name:, concept_id:, value: 'value_coded', join: 'INNER')
    query = model
    unless [name.class, concept_id.class].include?(Array)
      return query.joins(format(QUERY_STRING,
                                join: join,
                                name: name,
                                concept_id: concept_id,
                                value: value))
                  .select("#{name}.#{value} AS #{name}")
    end

    construct_query(model, name, concept_id, value, join)
  end

  def self.construct_query(model, name, concept_id, value, join)
    query = model
    concept_id.each_with_index do |concept, index|
      query = query.joins(format(QUERY_STRING,
                                 join: join,
                                 name: name[index],
                                 concept_id: concept,
                                 value: value))
                   .select("#{name[index]}.#{value} AS #{name[index]}")
    end
    query
  end
end