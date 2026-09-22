# frozen_string_literal: true

module Api
  module V1
    module Patients
      class ProgramsController < ApplicationController
        # TODO: Refactor much of the logic in this controller into a service

        def index
          render json: PatientProgram.where(patient_id: params[:patient_id])
        end

        def show
          render json: patient_program!
        end

        def create
          create_params = params.permit(:program_id, :date_enrolled)
          create_params[:date_enrolled] ||= Time.now
          create_params[:location_id] = Location.current.id
          create_params[:creator] = User.current.id
          create_params[:patient_id] = params[:patient_id]

          program = Program.find(create_params[:program_id])
          patient = Patient.find(create_params[:patient_id])

          if PatientProgram.where(program_id: program.id, patient_id: patient.id).exists?
            render json: { errors: ['Patient already enrolled in program'] }, status: :conflict
            return
          end

          patient_program = PatientProgramService.new.create(
            patient: patient,
            program: program,
            date_enrolled: create_params[:date_enrolled],
            location: Location.find(create_params[:location_id]),
            user: User.find(create_params[:creator])
          )

          if patient_program.errors.empty?
            render json: patient_program, status: :created
          else
            render json: patient_program.errors, status: :bad_request
          end
        end

        def update
          p_program = patient_program!
          date_enrolled = params.require(:date_enrolled)

          if p_program.update(date_enrolled:, location_id: Location.current.id)
            render json: p_program
          else
            render json: { errors: p_program.errors }, status: :bad_request
          end
        end

        def destroy
          p_program = patient_program

          if p_program.nil? || p_program.destroy
            render status: :no_content
          else
            render json: :p_program.errors, status: :internal_server_error
          end
        end

        private

        def patient_program
          PatientProgram.find_by(patient_id: params[:patient_id], program_id: params[:id])
        end

        def patient_program!
          PatientProgram.find_by!(patient_id: params[:patient_id], program_id: params[:id])
        end
      end
    end
  end
end
