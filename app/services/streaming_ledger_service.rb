# frozen_string_literal: true

class StreamingLedgerService
  STALE_LOCK_THRESHOLD = 15.minutes
  STALE_SENT_THRESHOLD = 15.minutes
  DEFAULT_MAX_ATTEMPTS = 20

  # Statuses no worker owns. `sent` is claimable too, but only once it is older
  # than STALE_SENT_THRESHOLD (the worker died mid-request). `sending` and
  # `dead` are never claimable: the former belongs to a live worker, the latter
  # only leaves through reset_dead!.
  CLAIMABLE_STATUSES = %w[queued failed retrying acknowledged].freeze

  class << self
    def find_or_create!(patient_id:, program_id:, stream_date:, location_id: nil)
      resolved_location_id = location_id || Location.current_health_center&.id
      stream_key = build_stream_key(patient_id, program_id, stream_date, resolved_location_id)

      StreamingLedger.find_or_create_by!(stream_key:) do |ledger|
        ledger.patient_id = patient_id
        ledger.program_id = program_id
        ledger.stream_date = stream_date
        ledger.status = 'queued'
      end
    end

    def mark_queued!(ledger)
      ledger.update!(status: 'queued', sent_at: nil, acknowledged_at: nil, error_message: nil, locked_at: nil, next_attempt_at: nil)
    end

    def mark_sending!(ledger)
      ledger.update!(status: 'sending', locked_at: Time.current)
    end

    def mark_sent!(ledger, response_code: nil, payload_hash: nil)
      ledger.update!(
        status: 'sent',
        payload_hash: payload_hash,
        response_code: response_code,
        sent_at: Time.current,
        error_message: nil,
        locked_at: Time.current,
        next_attempt_at: nil
      )
    end

    def mark_acknowledged!(ledger, response_code: nil)
      ledger.update!(
        status: 'acknowledged',
        acknowledged_at: Time.current,
        response_code: response_code,
        error_message: nil,
        locked_at: nil
      )
    end

    def mark_retrying!(ledger)
      record_failure!(ledger)
    end

    def mark_failed!(ledger, error_message:, response_code: nil, permanent: false, transient: true)
      record_failure!(ledger, error_message:, response_code:, permanent:, transient:)
    end

    # Single transition point for every failure, whatever raised it: a network
    # error inside StreamingService, a job that blew up before or after the
    # POST, or a worker that died holding a claim. Increments retry_count
    # exactly once.
    #
    # Only two things make a row `dead`:
    # - `permanent: true`: central rejected the payload (4xx), so resending the
    #   same data cannot help.
    # - an unclassified error (a bug building the payload, bad local data)
    #   repeated max_attempts times.
    # Transient errors (network, timeouts, 5xx, dead workers) never kill a row.
    # An outage of any length must drain on its own once central is back, so
    # they keep retrying at the capped backoff.
    def record_failure!(ledger, error_message: nil, response_code: nil, permanent: false, transient: true)
      new_retry_count = ledger.retry_count.to_i + 1
      max_attempts = ledger.max_attempts || DEFAULT_MAX_ATTEMPTS

      attributes = {
        error_message: error_message,
        response_code: response_code,
        retry_count: new_retry_count,
        last_error_at: Time.current,
        locked_at: nil
      }

      if permanent || (!transient && new_retry_count >= max_attempts)
        ledger.update!(attributes.merge(status: 'dead', next_attempt_at: nil))
      else
        ledger.update!(
          attributes.merge(
            status: 'retrying',
            next_attempt_at: Time.current + StreamingLedger.next_delay(new_retry_count)
          )
        )
      end

      ledger
    end

    # True when a job is already due to pick this row up later: it is serving
    # a backoff window, or the drain has reserved it for a queued job. A live
    # write must not enqueue another job, which would bypass the backoff. The
    # pending send builds its payload when it runs, so it includes the write.
    def deferred?(ledger)
      return false unless ledger.status.in?(%w[queued retrying failed])

      ledger.next_attempt_at.present? && ledger.next_attempt_at > Time.current
    end

    # True while a worker owns the row: it has been claimed, or its POST is
    # still within the time it could legitimately take.
    def in_flight?(ledger)
      return true if ledger.sending?
      return false unless ledger.sent?

      ledger.sent_at.present? && ledger.sent_at >= STALE_SENT_THRESHOLD.ago
    end

    def release_ledger(ledger, error_message: nil)
      record_failure!(ledger, error_message:)
    end

    # Returns claims whose worker never finished (killed process, lost DB
    # connection). A dead worker says nothing about the payload, so this is a
    # transient failure: it backs off but never makes the row `dead`.
    def release_stale_claims!(threshold: STALE_LOCK_THRESHOLD)
      StreamingLedger
        .where(status: 'sending')
        .where('locked_at < ?', threshold.ago)
        .find_each do |ledger|
          record_failure!(ledger, error_message: "stale claim released after #{threshold.inspect}")
        end
    end

    def find_by_stream_key(stream_key)
      StreamingLedger.find_by(stream_key: stream_key)
    end

    def query(status: nil, start_date: nil, end_date: nil, patient_id: nil, program_id: nil, stream_key: nil)
      scope = StreamingLedger.all
      statuses = normalize_statuses(status)
      scope = scope.where(status: statuses) if statuses.present?
      scope = scope.where(patient_id: patient_id) if patient_id.present?
      scope = scope.where(program_id: program_id) if program_id.present?
      scope = scope.where(stream_key: stream_key) if stream_key.present?

      if start_date.present?
        parsed_start_date = parse_date(start_date)
        scope = scope.where('stream_date >= ?', parsed_start_date)
      end

      if end_date.present?
        parsed_end_date = parse_date(end_date)
        scope = scope.where('stream_date <= ?', parsed_end_date)
      end

      scope.order(created_at: :desc)
    end

    def build_stream_key(patient_id, program_id, stream_date, location_id = nil)
      [location_id, patient_id, program_id, stream_date.to_date.iso8601].join(':')
    end

    def replayable_streams
      StreamingLedger.where(status: %w[queued failed retrying]).order(:updated_at)
    end

    # Rows the scheduled drain is allowed to pick up on its own. `dead` is
    # deliberately excluded: it means central rejected the payload
    # permanently, so only an explicit manual replay may retry it.
    def due_streams(limit:)
      StreamingLedger
        .where(status: %w[queued failed retrying])
        .or(StreamingLedger.where(status: 'sent').where('sent_at < ?', STALE_SENT_THRESHOLD.ago))
        .where('next_attempt_at IS NULL OR next_attempt_at <= ?', Time.current)
        .order(:created_at)
        .limit(limit)
    end

    # Atomic claim and the only way a row enters `sending`. It succeeds only
    # from a status nobody owns, so a row that is `sending`, or `sent` with a
    # request still running, cannot be claimed a second time. The database
    # serialises the UPDATE on the row, so of two workers racing, exactly one
    # changes it. Only StreamingJob calls this; everything else just enqueues.
    def claim_ledger(ledger)
      StreamingLedger
        .where(id: ledger.id)
        .where('status IN (?) OR (status = ? AND (sent_at IS NULL OR sent_at < ?))',
               CLAIMABLE_STATUSES, 'sent', STALE_SENT_THRESHOLD.ago)
        .update_all(status: 'sending', locked_at: Time.current, next_attempt_at: nil, updated_at: Time.current) > 0
    end

    # Marks a due row as handed to a job, so the next drain run does not
    # enqueue it again while that job waits in the queue. The status is left
    # alone so the job can still claim it. The future next_attempt_at hides the
    # row from due_streams, and from live writes through deferred?. If the job
    # is lost, the row becomes due again when the window ends.
    def reserve_for_drain(ledger, window: STALE_LOCK_THRESHOLD)
      StreamingLedger
        .where(id: ledger.id, status: ledger.status)
        .where('next_attempt_at IS NULL OR next_attempt_at <= ?', Time.current)
        .update_all(next_attempt_at: Time.current + window, updated_at: Time.current) > 0
    end

    # Operator escape hatch for a `dead` row: back to `queued` with a fresh
    # attempt budget. Atomic, so two replay calls cannot both reset it.
    def reset_dead!(ledger)
      StreamingLedger
        .where(id: ledger.id, status: 'dead')
        .update_all(status: 'queued', retry_count: 0, next_attempt_at: nil, locked_at: nil,
                    error_message: nil, updated_at: Time.current) > 0
    end

    private

    def normalize_statuses(status)
      return [] if status.blank?

      Array(status).flat_map do |value|
        value.to_s.split(',').map(&:strip).reject(&:blank?)
      end.uniq
    end

    def parse_date(date_value)
      Date.parse(date_value.to_s)
    rescue Date::Error
      raise ArgumentError, "Invalid date: #{date_value}"
    end
  end
end
