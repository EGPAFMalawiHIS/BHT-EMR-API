# frozen_string_literal: true

class StreamIncompleteVisitsJob < ApplicationJob
  self.queue_adapter = :solid_queue

  PROGRAM_ID = 1 # TODO: make this dynamic for all programs

  def perform
    date = Date.today - 1
    patient_ids = program_incomplete_visits(date:)
    return if patient_ids.blank?

    # Ledger rows are written on the primary connection; only the job enqueue
    # needs the queue database.
    patient_ids.each do |patient_id|
      StreamingLedgerService.find_or_create!(patient_id:, program_id: PROGRAM_ID, stream_date: date)
    end

    begin
      ActiveRecord::Base.establish_connection(:queue)

      patient_ids.each do |patient_id|
        StreamingJob.perform_later(
          patient_id:,
          program_id: PROGRAM_ID,
          date: date.strftime('%Y-%m-%d')
        )
      end
    ensure
      ActiveRecord::Base.establish_connection(:primary)
    end
  end

  def program_incomplete_visits(date:)
    ArtService::DataCleaningTool.new(
      start_date: date.beginning_of_day,
      end_date: date.end_of_day,
      tool_name: 'INCOMPLETE VISITS'
    ).results&.keys
  end
end
