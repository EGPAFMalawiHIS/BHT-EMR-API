class StreamingJob < ApplicationJob
  # Only route through SolidQueue when streaming is explicitly enabled;
  # otherwise inherit ApplicationJob's default (:async).
  self.queue_adapter = :solid_queue if StreamingSettings.enabled?

  def perform(patient_id:, program_id:, date:)
    StreamingService.new(patient_id:, program_id:, date:).stream_visit
  end
end