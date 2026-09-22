# frozen_string_literal: true

# Class managing patient program details
class PatientProgramService
  def create(patient:, program:, date_enrolled: nil, location: nil, user: nil)
    date_enrolled ||= Time.now
    location ||= Location.current
    user ||= User.current
    return if program.blank? || patient.blank?

    patient_program = find_patient_program(patient:, program:)
    return patient_program unless patient_program.blank?

    ActiveRecord::Base.transaction do
      patient_program = PatientProgram.create(patient:, program:, date_enrolled:,
                                              location:, creator: user.id)
      initial_state = initial_program_state(program)
      unless initial_state.blank?
        PatientState.create(patient_program_id: patient_program.id, start_date: date_enrolled,
                            state: initial_state.id, creator: user.id)
      end
    end

    patient_program
  end

  def find_patient_program(patient:, program:)
    PatientProgram.where(patient:, program:).first
  end

  def initial_program_state(program)
    # For HTN program, prefer "On treatment" as initial state
    if program.name == 'HYPERTENSION PROGRAM'
      state = ProgramWorkflowState.joins(:program_workflow)
                                  .joins("INNER JOIN concept_name ON concept_name.concept_id = program_workflow_state.concept_id")
                                  .where(initial: 1, terminal: 0, program_workflow: { program_id: program.id })
                                  .where("concept_name.name LIKE ?", "%On treatment%")
                                  .first
      return state if state
    end
    
    # Default: first initial state for other programs
    ProgramWorkflowState.joins(:program_workflow)
                        .where(initial: 1, terminal: 0, program_workflow: { program_id: program.id })
                        .order(:concept_id)
                        .first
  end
end
