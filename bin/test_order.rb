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

  threads = []
  num.times.each_slice(pool_size) do |batch|
    batch.each do
      threads << Thread.new do
        User.current = User.first
        Location.current = Location.find(GlobalProperty.find_by(property: 'current_health_center_id').property_value)
        params = generate_patient_params
        person = create_person_with_name(params)
        patient = create_patient(program, person)
        patients << patient
      end
    end
    threads.each(&:join)
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
    middle_name: Faker::Name.middle_name,
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
    tests: tests.map { |test| {concept_id: test} },
    start_date: Date.today,
    accession_number: accession,
    target_lab: GlobalProperty.find_by_property('target.lab')&.property_value || GlobalProperty.find_by_property('current_health_center_name')&.property_value || 'Kamuzu Central Hospital',
    reason_for_test_id: 432,
    requesting_clinician: Faker::Name.name,
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
  tests = []
  specimen = specimens.sample
  while tests.empty?
    tests = Lab::ConceptsService.test_types(name: nil, specimen_type: specimen['name']).map(&:concept_id)
    specimen = specimens.sample
  end

  sample_size = tests.size > 4 ? 3 : 1

  {specimen:, tests: tests.take(sample_size)}
end

def create_orders(patients)
  program = Program.find_by_name('OPD Program')
  specimens = fetch_specimens
  orders = []
  pool_size = database_pool_size
  accessions = accession_nums(num: patients.size)

  mutex = Mutex.new
  threads = []

  patients.each_slice(pool_size) do |batch|
    batch.each do |patient|
      threads << Thread.new do
        User.current = User.first
        Location.current = Location.find(GlobalProperty.find_by(property: 'current_health_center_id').property_value)
        order = create_order_for_patient(patient, specimens, program, accessions[patients.index(patient)])
        mutex.synchronize { orders << order }
      end
    end
    threads.each(&:join)
  end

  orders
end

def fetch_specimens
  Lab::ConceptsService.specimen_types.map do |specimen|
    { concept_id: specimen['concept_id'], name: specimen['name'] }
  end
end

def create_order_for_patient(patient, specimens, program, accession)
  test_data = get_tests(specimens)
  params = order_params(patient:, accession:, specimen: test_data[:specimen], tests: test_data[:tests], program:)
  order = Lab::OrdersService.order_test(params)
  Lab::PushOrderJob.perform_now(order.fetch(:order_id))
  order
end

def void_patients(patients)
  patients.each do |patient|
    patient.void('voided by test script')
  end
end

patients = []
orders = []

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
      file.puts("#{order[:accession_number]},#{order[:patient_id]},#{order[:specimen][:concept_id]},#{order[:tests].map { |test| test[:concept_id] }.join(',')}")
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
main(num: num)