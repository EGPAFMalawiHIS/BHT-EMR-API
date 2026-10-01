# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StreamingJob do
  let(:patient_id) { 42 }
  let(:program_id) { 1 }
  let(:date) { '2026-09-10' }
  let(:service) { instance_double(StreamingService) }

  before do
    StreamingLedger.delete_all
    allow(Location).to receive(:current_health_center).and_return(double(id: 12))
    allow(StreamingService).to receive(:new).and_return(service)
  end

  def run_job(**extra)
    described_class.new.perform(patient_id:, program_id:, date:, **extra)
  end

  def ledger
    StreamingLedger.find_by!(patient_id:, program_id:, stream_date: date.to_date)
  end

  it 'sends an unowned row and passes a reloaded ledger that is sending' do
    allow(service).to receive(:stream_visit) do |ledger:|
      expect(ledger.status).to eq('sending')
      StreamingLedgerService.mark_acknowledged!(ledger, response_code: 200)
    end

    run_job

    expect(service).to have_received(:stream_visit)
    expect(ledger.status).to eq('acknowledged')
  end

  it 'does not send a row whose send is still in progress, and retries once later' do
    existing = StreamingLedgerService.find_or_create!(patient_id:, program_id:, stream_date: date.to_date)
    StreamingLedgerService.mark_sent!(existing, payload_hash: 'abc')
    delayed = double(perform_later: true)
    allow(described_class).to receive(:set).with(wait: described_class::IN_FLIGHT_RETRY_WAIT).and_return(delayed)
    allow(service).to receive(:stream_visit)

    run_job

    expect(service).not_to have_received(:stream_visit)
    expect(delayed).to have_received(:perform_later).with(patient_id:, program_id:, date:, requeued: true)
  end

  it 'does not requeue a second time' do
    existing = StreamingLedgerService.find_or_create!(patient_id:, program_id:, stream_date: date.to_date)
    StreamingLedgerService.mark_sent!(existing, payload_hash: 'abc')
    allow(described_class).to receive(:set)
    allow(service).to receive(:stream_visit)

    run_job(requeued: true)

    expect(described_class).not_to have_received(:set)
  end

  it 'records an error raised before the POST instead of leaving the row sending' do
    allow(service).to receive(:stream_visit).and_raise(NoMethodError, 'boom')

    expect { run_job }.not_to raise_error

    expect(ledger.status).to eq('retrying')
    expect(ledger.retry_count).to eq(1)
    expect(ledger.error_message).to include('boom')
  end

  it 'records an unlisted network error raised after the row was marked sent' do
    allow(service).to receive(:stream_visit) do |ledger:|
      StreamingLedgerService.mark_sent!(ledger, payload_hash: 'abc')
      raise Errno::EPROTO, 'protocol error'
    end

    expect { run_job }.not_to raise_error

    expect(ledger.status).to eq('retrying')
    expect(ledger.next_attempt_at).to be > Time.current
  end

  it 'makes a row dead after repeated unclassified errors' do
    existing = StreamingLedgerService.find_or_create!(patient_id:, program_id:, stream_date: date.to_date)
    existing.update_columns(retry_count: existing.max_attempts - 1, status: 'retrying')
    allow(service).to receive(:stream_visit).and_raise(NoMethodError, 'boom')

    run_job

    expect(ledger.status).to eq('dead')
  end

  it 'does not count a failure already recorded by StreamingService, and does not raise' do
    allow(service).to receive(:stream_visit) do |ledger:|
      StreamingLedgerService.mark_failed!(ledger, error_message: 'refused')
      raise StreamingService::DeliveryError, 'refused'
    end

    expect { run_job }.not_to raise_error

    expect(ledger.retry_count).to eq(1)
    expect(ledger.status).to eq('retrying')
  end
end

RSpec.describe StreamingService do
  let(:ledger) do
    StreamingLedgerService.find_or_create!(patient_id: 42, program_id: 1, stream_date: Date.new(2026, 9, 10),
                                           location_id: 12)
  end
  let(:client) { double('client') }
  let(:service) do
    described_class.allocate.tap do |s|
      s.patient = double(id: 42, name: 'Test Patient', as_json: {}, visit_data: [], current_program: nil)
      s.program_id = 1
      s.date = '2026-09-10'
      s.client = client
      s.config = { 'url' => 'http://central.test/stream' }
    end
  end

  before do
    StreamingLedger.delete_all
    allow(Location).to receive(:current_health_center).and_return(double(id: 12))
    allow(ArtService::PatientStreamBuilder).to receive(:new).and_return(double(build: {}))
    allow(service).to receive(:to_compressed_json) { |data| data }
    allow(service).to receive(:ip_address).and_return('10.0.0.1')
    StreamingLedgerService.claim_ledger(ledger)
    ledger.reload
  end

  def http_error(code)
    RestClient::ExceptionWithResponse.new(double(code: code, body: '', to_s: ''), code)
  end

  it 'sends the stream key as meta and as an Idempotency-Key header' do
    allow(client).to receive(:post).and_return(double(code: 201))

    service.stream_visit(ledger:)

    expect(client).to have_received(:post) do |body, headers|
      expect(JSON.parse(body)['meta']['stream_key']).to eq(ledger.stream_key)
      expect(headers).to eq('Idempotency-Key' => ledger.stream_key)
    end
    expect(ledger.reload.status).to eq('acknowledged')
  end

  it 'treats a 409 as already stored' do
    allow(client).to receive(:post).and_raise(http_error(409))

    expect { service.stream_visit(ledger:) }.not_to raise_error

    expect(ledger.reload.status).to eq('acknowledged')
    expect(ledger.response_code).to eq(409)
  end

  it 'marks a 422 dead and raises DeliveryError' do
    allow(client).to receive(:post).and_raise(http_error(422))

    expect { service.stream_visit(ledger:) }.to raise_error(StreamingService::DeliveryError)

    expect(ledger.reload.status).to eq('dead')
  end

  it 'retries a 500 with backoff' do
    allow(client).to receive(:post).and_raise(http_error(500))

    expect { service.stream_visit(ledger:) }.to raise_error(StreamingService::DeliveryError)

    expect(ledger.reload.status).to eq('retrying')
    expect(ledger.next_attempt_at).to be > Time.current
  end

  it 'retries a network error that used to escape the rescue' do
    allow(client).to receive(:post).and_raise(Errno::ENETUNREACH)

    expect { service.stream_visit(ledger:) }.to raise_error(StreamingService::DeliveryError)

    expect(ledger.reload.status).to eq('retrying')
  end
end
