# frozen_string_literal: true

class ClearFinishedJob < ApplicationJob
  # Only route through SolidQueue when streaming is explicitly enabled;
  # otherwise inherit ApplicationJob's default (:async).
  self.queue_adapter = :solid_queue if StreamingSettings.enabled?

  def perform
    SolidQueue::Job.clear_finished_in_batches
  end
end
