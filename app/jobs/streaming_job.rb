# frozen_string_literal: true

class StreamingJob < ApplicationJob
  self.queue_adapter = :solid_queue

  # How long to wait before trying again when another worker is mid-send for
  # the same visit. Longer than the request timeout in StreamingService.
  IN_FLIGHT_RETRY_WAIT = 2.minutes

  # Low-level failures that say nothing about the payload. They are retried
  # with backoff and never make a row `dead`.
  TRANSIENT_ERRORS = [SystemCallError, IOError, SocketError, Timeout::Error].freeze

  def perform(patient_id:, program_id:, date:, requeued: false)
    stream_date = date.to_date
    ledger = StreamingLedgerService.find_or_create!(patient_id:, program_id:, stream_date: stream_date)

    # Every enqueuer (live clinical writes, the scheduled drain, the daily
    # jobs, manual replay) ends up here, and this claim is the only thing that
    # moves a row into `sending`. It refuses rows another worker owns.
    unless StreamingLedgerService.claim_ledger(ledger)
      requeue_if_in_flight(ledger.reload, patient_id:, program_id:, date:, requeued:)
      return
    end

    # claim_ledger writes with update_all, which does not touch this object.
    ledger.reload

    StreamingService.new(patient_id:, program_id:, date: stream_date.to_s).stream_visit(ledger:)
  rescue StreamingService::DeliveryError
    # StreamingService has already recorded this on the ledger (retrying or
    # dead with backoff). The ledger drives the retry, so the job ends here
    # instead of also landing in Solid Queue's failed executions, where
    # `rails streaming:failed` would retry it a second time without backoff.
    nil
  rescue StandardError => e
    raise e if ledger.nil? # nothing to record against; let Solid Queue keep it

    record_unhandled_failure(ledger, e)
  end

  private

  # A clinical write that lands while the same visit is mid-send may not be in
  # the payload already on the wire. Try once more after the send finishes,
  # when the row is claimable again and the payload is rebuilt with the write.
  # One requeue is enough: a later write enqueues its own job.
  def requeue_if_in_flight(ledger, patient_id:, program_id:, date:, requeued:)
    return if requeued
    return unless StreamingLedgerService.in_flight?(ledger)

    self.class.set(wait: IN_FLIGHT_RETRY_WAIT)
        .perform_later(patient_id:, program_id:, date:, requeued: true)
  end

  # Anything StreamingService did not record: an error before the POST (missing
  # config, patient not found, payload builder bug) or an unlisted error during
  # it. The row is still `sending` or `sent` in that case, so recording here
  # cannot double-count with StreamingService.
  def record_unhandled_failure(ledger, error)
    ledger.reload
    return unless ledger.sending? || ledger.sent?

    Rails.logger.error("Streaming failed for #{ledger.stream_key}: #{error.class}: #{error.message}")
    StreamingLedgerService.record_failure!(
      ledger,
      error_message: "#{error.class}: #{error.message}",
      transient: TRANSIENT_ERRORS.any? { |klass| error.is_a?(klass) }
    )
  rescue StandardError => e
    # If even the ledger write fails (database down), the row stays `sending`
    # and release_stale_claims! recovers it. Keep the job visible as failed.
    Rails.logger.error("Could not record streaming failure for #{ledger&.stream_key}: #{e.message}")
    raise error
  end
end
