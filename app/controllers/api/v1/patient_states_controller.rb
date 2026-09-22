# frozen_string_literal: true

module Api
  module V1
    class PatientStatesController < ApplicationController
      def index
        date = params[:date]&.to_date || Date.today
        states = service.all_patient_states program, patient, date
        render json: states
      end

      def create
        state, = params.require %i[state]
        date = params[:date]&.to_date || Date.today
        
        # For HTN program, prevent creating "Alive" state if initial state already exists
        if program.name == 'HYPERTENSION PROGRAM' && state == 160
          existing_initial = PatientState.where(patient_program: find_patient_program(program, patient, date))
                                      .where(state: [162, 166, 167]) # On treatment, Symptomatic, Lifestyle
                                      .where('start_date <= ?', date)
                                      .exists?
          if existing_initial
            render json: { error: 'Initial state already exists for HTN program' }, status: :unprocessable_entity
            return
          end
        end
        
        patient_state = service.create_patient_state program, patient, state, date
        render json: patient_state, status: :created
      end

      def destroy
        state = PatientState.find(params[:id])
        reason = params[:reason] || "Voided by #{User.current.username}"
        service.void_state(state, reason)
        render status: :no_content
      end

      private

      def program
        Program.find(params[:program_id])
      end

      def patient
        Patient.find(params[:program_patient_id])
      end

      def service
        PatientStateService.new
      end

      def find_patient_program(program, patient, ref_date)
        PatientProgram.where(program:, patient:)
                      .where('DATE(date_enrolled) <= ?', ref_date)
                      .last
      end
    end
  end
end
