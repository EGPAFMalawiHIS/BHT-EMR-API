# frozen_string_literal: true

require 'csv'
require 'faker'
require 'yaml'

LOGGER = Logger.new($stdin)
ActiveRecord::Base.logger = LOGGER

def create_patients(num:)
  patients = []
  program = Program.find_by_name('OPD Program')
  pool_size = database_pool_size
  num.times.each_slice(pool_size) do |batch|
    batch.each do
      User.current = User.first
      Location.current = Location.find(GlobalProperty.find_by(property: 'current_health_center_id').property_value)
      params = generate_patient_params
      person = create_person_with_name(params)
      patient = create_patient(program, person)
      patients << patient
    end
  end
  patients
end

def generate_patient_params
  {
    gender: %w[M F].sample,
    birthdate: Faker::Date.birthday(min_age: 1, max_age: 100),
    birthdate_estimated: [true, false].sample,
    given_name: Faker::Name.first_name,
    family_name: Faker::Name.last_name,
    middle_name: Faker::Name.middle_name
  }
end

def create_person_with_name(params)
  person = PersonService.new.create_person(params)
  PersonService.new.create_person_name(person, params)
  person
end

def create_patient(program, person)
  PatientService.new.create_patient(program, person)
end

def database_pool_size
  config = YAML.load_file('config/database.yml', aliases: true)
  config[Rails.env]['pool'].to_i
end

def order_params(patient:, accession:, specimen:, tests:, program:)
  {
    program_id: program.id,
    patient_id: patient.patient_id,
    specimen:,
    tests: tests.map { |test| { concept_id: test } },
    start_date: Date.today,
    accession_number: accession,
    target_lab: GlobalProperty.find_by_property('target.lab')&.property_value || GlobalProperty.find_by_property('current_health_center_name')&.property_value || 'Kamuzu Central Hospital',
    reason_for_test_id: 432,
    requesting_clinician: Faker::Name.name
  }
end

def accession_nums(num:)
  accessions = []

  num.times do
    accessions << Lab::AccessionNumberService.next_accession_number(Date.today)
  end
  accessions
end

def get_tests(specimens)
  tests_to_be_used = []
  tests_used = ConceptName.where(
      name: ['Liver function tests', 'fbc', 'viral load', 'Renal Function test']
      ).map(&:concept_id)
  tests = []
  selected_tests = []
  specimen = specimens.select { |sp| %w[plasma blood].include?(sp[:name].downcase) }.sample
  while tests.empty?
    tests = Lab::ConceptsService.test_types(name: nil, specimen_type: specimen[:name]).map(&:concept_id)
    selected_tests = tests.select { |element| tests_used.include?(element) }
    selected_tests ||= tests
  end
  selected_tests.each do |test|
    tests_to_be_used << { specimen:, tests: [test] }
  end
  tests_to_be_used
end

def create_orders(patients)
  program = Program.find_by_name('OPD Program')
  specimens = fetch_specimens
  orders = []
  accessions = accession_nums(num: patients.size * 4)
  puts accessions
  User.current = User.first
  Location.current = Location.find(GlobalProperty.find_by(property: 'current_health_center_id').property_value)

  patients.each do |patient|
    tests_data = get_tests(specimens)
    tests_data.each do |specimen|
      order = create_order_for_patient(patient, specimen, program, accessions.shift)
      orders << order
    end
  end

  orders
end

def fetch_specimens
  specimens = Lab::ConceptsService.specimen_types.map do |specimen|
    { concept_id: specimen['concept_id'], name: specimen['name'] }
  end
  # we need to reject the specimen with the name 'Pulmonary effusion'
  specimens.reject { |specimen| specimen[:name] == 'Pulmonary effusion' }
end

def create_order_for_patient(patient, specimen, program, accession)
  params = order_params(patient:, accession:, specimen: specimen[:specimen], tests: specimen[:tests], program:)
  order = Lab::OrdersService.order_test(params)
  Lab::PushOrderJob.perform_now(order.fetch(:order_id))
  order
end

def void_patients(patients)
  patients.each do |patient|
    patient.void('voided by test script')
  end
end

def main(num:)
  patients = create_patients(num:)
  orders = create_orders(patients)
  # we need to log the patients created and the orders created, we can output them to a csv file

  # output to csv
  File.open('./log/patients.csv', 'w') do |file|
    patients.each do |patient|
      file.puts("#{patient.patient_id},#{patient.person.names.first.given_name},#{patient.person.names.first.family_name},#{patient.person.names.first.middle_name} ")
    end
  end

  File.open('./log/orders.csv', 'w') do |file|
    orders.each do |order|
      file.puts("#{order[:accession_number]},#{order[:patient_id]},#{order[:specimen][:concept_id]},#{order[:tests].map do |test|
        test[:concept_id]
      end.join(',')}")
    end
  end
  puts "\e[32m#{patients.size} patients and #{orders.size} orders have been created\e[0m"
rescue StandardError => e
  void_patients(patients)
  LOGGER.error(e.message)
  LOGGER.error(e.backtrace.join("\n"))
  puts "\e[31mAn error occurred, voided all patients created\e[0m"
end

# we need to prompt the user for the number of patients to create
print 'Enter the number of patients to create: '
num = gets.chomp.to_i
main(num:)
