# frozen_string_literal: true

# Scheduled drain for the streaming ledger. Registered in config/recurring.yml
# (see config/recurring.yml.example):
#
#   replay_pending_streams:
#     class: ReplayPendingStreamsJob
#     queue: streaming
#     schedule: every 5 minutes
#
# The ledger, not the job queue, is the source of truth: this job only picks up
# rows that are due, reserves them atomically, and hands them to StreamingJob,
# which claims each row before sending it.

class ReplayPendingStreamsJob < ApplicationJob
  self.queue_adapter = :solid_queue

  BATCH_SIZE = 100

  def perform
    return unless central_reachable?

    StreamingLedgerService.release_stale_claims!
    process_due_streams
  end

  private

  def central_reachable?
    config = cdr_config
    return true if config.blank?

    return true unless config['health_check_endpoint'].present?

    client = RestClient::Resource.new(
      config['url'],
      user: config['username'],
      password: config['password'],
      headers: { content_type: :json },
      verify_ssl: OpenSSL::SSL::VERIFY_NONE,
      open_timeout: 5,
      timeout: 5
    )

    endpoint = config['health_check_endpoint'].to_s
    client[endpoint.start_with?('/') ? endpoint : "/#{endpoint}"].get
    true
  rescue StandardError => e
    Rails.logger.warn("Central server not reachable: #{e.message}")
    false
  end

  def cdr_config
    YAML.safe_load(File.read('config/application.yml'), aliases: true)['cdr']
  rescue StandardError => e
    Rails.logger.warn("Unable to read CDR config: #{e.message}")
    nil
  end

  # Reserve, do not claim: StreamingJob performs the claim, and a row this job
  # had already moved to `sending` could never be claimed by it. The
  # reservation only stops the next run from enqueueing the same row again
  # while its job waits in the queue.
  def process_due_streams
    StreamingLedgerService.due_streams(limit: BATCH_SIZE).each do |ledger|
      next unless StreamingLedgerService.reserve_for_drain(ledger)

      StreamingJob.perform_later(
        patient_id: ledger.patient_id,
        program_id: ledger.program_id,
        date: ledger.stream_date.to_s
      )
    end
  end
end
