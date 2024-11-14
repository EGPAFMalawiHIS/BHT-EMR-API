# frozen_string_literal: true

require 'faker'
require 'yaml'

def create_patients(num:)
  patients = []
  program = Program.find_by_name('OPD Program')
  pool_size = database_pool_size

  threads = []
  num.times.each_slice(pool_size) do |batch|
    batch.each do
      threads << Thread.new do
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
  person = PersonService.create_person(params)
  PersonService.create_person_name(person, params)
  person
end

def create_patient(program, person)
  PatientService.create_patient(program, person)
end

def database_pool_size
  config = YAML.load_file('config/database.yml')
  config[Rails.env]['pool'].to_i
end


