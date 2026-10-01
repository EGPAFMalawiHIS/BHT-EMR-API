# frozen_string_literal: true

require 'digest'
require 'socket'

class StreamingService
  class TransientError < StandardError; end
  class PermanentError < StandardError; end

  # Raised by stream_visit after a delivery failure has been recorded on the
  # ledger. Callers must not record it again. The original error is `cause`.
  class DeliveryError < StandardError; end

  NETWORK_ERRORS = [
    RestClient::Exceptions::Timeout,
    RestClient::ServerBrokeConnection,
    Errno::ECONNREFUSED,
    Errno::ECONNRESET,
    Errno::EHOSTUNREACH,
    Errno::ENETUNREACH,
    Errno::ENETDOWN,
    Errno::ETIMEDOUT,
    Errno::EPIPE,
    Errno::EADDRNOTAVAIL,
    Net::OpenTimeout,
    Net::ReadTimeout,
    EOFError,
    SocketError,
    OpenSSL::SSL::SSLError
  ].freeze

  # Central already holds this record, so the delivery succeeded.
  ALREADY_STORED_CODES = [409].freeze

  attr_accessor :patient, :program_id, :date, :client, :config

  include Utils::JsonUtils

  def initialize(patient_id:, program_id:, date:)
    setup_remote_config
    @patient = Patient.find(patient_id)
    @program_id = program_id
    @date = date
  end

  def setup_remote_config
    @config = YAML.safe_load(
      File.read('config/application.yml'), aliases: true
    )['cdr']

    if config.empty?
      raise 'Streaming config not found or not properly set,
             please refer to the application.yml.example'
    end

    @client = RestClient::Resource.new(
      config['url'],
      user: config['username'],
      password: config['password'],
      headers: { content_type: :json },
      verify_ssl: OpenSSL::SSL::VERIFY_NONE,
      open_timeout: 30,
      timeout: 60
    )
  end

  def stream_visit(ledger: nil)
    payload = to_compressed_json(
      {
        meta: {
          program_id:,
          ip_address:,
          location_id: Location.current_health_center&.id,
          # Stable per location/patient/program/day, so central can upsert on
          # it and treat a redelivery as a duplicate rather than a new visit.
          stream_key: ledger&.stream_key
        },
        payload: {
          raw: {
            patient: patient.as_json,
            encounters: patient.visit_data(program_id:, date:),
            current_program: patient.current_program(program_id:)
          },
          analytical: ArtService::PatientStreamBuilder.new(patient_id: patient.id, date:).build
        }
      }
    )

    # Hash of the exact bytes that go on the wire, recorded so a same-day edit
    # or second visit is visible in the ledger. This does not gate sending:
    # central's acknowledgement is not yet trustworthy enough to treat a
    # matching hash as proof it stored the data, so a resend is always allowed.
    payload_hash = Digest::SHA256.hexdigest(payload.to_json)

    # Marked sent before the POST. StreamingLedgerService.claim_ledger refuses
    # a `sent` row until it is stale, so neither the scheduled drain nor a live
    # clinical write can start a second send of this visit while this one runs.
    StreamingLedgerService.mark_sent!(ledger, payload_hash:) if ledger

    Rails.logger.info("Sending stream data for #{patient.name} on #{date} to #{config['url']}")

    headers = ledger ? { 'Idempotency-Key' => ledger.stream_key } : {}
    response = client.post(payload.to_json, headers)

    if ledger
      StreamingLedgerService.mark_acknowledged!(ledger, response_code: response.code)
    end

    response
  rescue *NETWORK_ERRORS, RestClient::ExceptionWithResponse => e
    response_code = e.respond_to?(:http_code) ? e.http_code : nil

    if ALREADY_STORED_CODES.include?(response_code)
      Rails.logger.info("Central already holds stream #{ledger&.stream_key} (#{response_code})")
      StreamingLedgerService.mark_acknowledged!(ledger, response_code:) if ledger
      return e.response
    end

    Rails.logger.error("Failed to send stream data #{e&.message}")
    raise e unless ledger

    StreamingLedgerService.mark_failed!(
      ledger,
      error_message: e.message,
      response_code:,
      permanent: classify(e) == PermanentError
    )
    raise DeliveryError, e.message
  end

  def ip_address
    Socket.ip_address_list.detect(&:ipv4_private?)&.ip_address
  end

  def classify(error)
    code = error.respond_to?(:http_code) ? error.http_code : nil
    return PermanentError if code && (400..499).cover?(code) && ![408, 425, 429].include?(code)
    TransientError
  end
end
