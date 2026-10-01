# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StreamingLedgerService do
  before(:each) do
    StreamingLedger.delete_all
  end

  let(:patient_id) { 42 }
  let(:program_id) { 7 }
  let(:stream_date) { Date.new(2026, 9, 10) }
  let(:location_id) { 12 }
  let(:stream_key) { '12:42:7:2026-09-10' }

  describe '.build_stream_key' do
    it 'combines the location, patient, program and date into a unique stream key' do
      expect(described_class.build_stream_key(patient_id, program_id, stream_date, location_id)).to eq(stream_key)
    end
  end

  describe '.find_or_create!' do
    it 'creates a queued ledger using the location-aware stream key' do
      ledger = described_class.find_or_create!(patient_id: patient_id, program_id: program_id,
                                              stream_date: stream_date, location_id: location_id)

      expect(ledger).to be_persisted
      expect(ledger.status).to eq('queued')
      expect(ledger.stream_key).to eq(stream_key)
      expect(StreamingLedger.column_names).not_to include('location_id')
    end

    it 'is idempotent for the same patient, program, date and location' do
      first_ledger = described_class.find_or_create!(patient_id: patient_id, program_id: program_id,
                                                   stream_date: stream_date, location_id: location_id)
      second_ledger = described_class.find_or_create!(patient_id: patient_id, program_id: program_id,
                                                    stream_date: stream_date, location_id: location_id)

      expect(first_ledger.id).to eq(second_ledger.id)
      expect(StreamingLedger.where(stream_key: stream_key).count).to eq(1)
    end
  end

  describe 'status lifecycle' do
    it 'updates the ledger from queued to sent to acknowledged and then retrying on failure' do
      ledger = described_class.find_or_create!(patient_id: patient_id, program_id: program_id,
                                              stream_date: stream_date, location_id: location_id)

      described_class.mark_sent!(ledger, response_code: 200, payload_hash: 'abc123')
      expect(ledger.reload.status).to eq('sent')
      expect(ledger.payload_hash).to eq('abc123')
      expect(ledger.response_code).to eq(200)

      described_class.mark_acknowledged!(ledger, response_code: 202)
      expect(ledger.reload.status).to eq('acknowledged')
      expect(ledger.response_code).to eq(202)

      described_class.mark_failed!(ledger, error_message: 'timeout', response_code: 500)
      expect(ledger.reload.status).to eq('retrying')
      expect(ledger.next_attempt_at).to be > Time.current
      expect(ledger.retry_count).to eq(1)
      expect(ledger.error_message).to eq('timeout')
    end

    it 'marks a ledger as retrying for replay and tracks retry count' do
      ledger = described_class.find_or_create!(patient_id: patient_id, program_id: program_id,
                                              stream_date: stream_date, location_id: location_id)

      described_class.mark_retrying!(ledger)

      expect(ledger.reload.status).to eq('retrying')
      expect(ledger.retry_count).to eq(1)
      expect(described_class.replayable_streams.where(stream_key: stream_key)).to exist
    end
  end

  describe '.query' do
    it 'filters ledgers by status and date range' do
      ledger = described_class.find_or_create!(patient_id: patient_id, program_id: program_id,
                                              stream_date: stream_date, location_id: location_id)
      described_class.mark_failed!(ledger, error_message: 'timeout', response_code: 500)

      results = described_class.query(status: 'retrying', start_date: stream_date, end_date: stream_date)

      expect(results.where(stream_key: stream_key)).to exist
      expect(results.where(patient_id: patient_id, program_id: program_id)).to exist
    end
  end

  def new_ledger
    described_class.find_or_create!(patient_id: patient_id, program_id: program_id,
                                    stream_date: stream_date, location_id: location_id)
  end

  describe '.claim_ledger' do
    it 'claims an unowned row exactly once' do
      ledger = new_ledger

      expect(described_class.claim_ledger(ledger)).to be(true)
      expect(ledger.reload.status).to eq('sending')
      expect(described_class.claim_ledger(ledger)).to be(false)
    end

    it 'refuses a row whose send is still in progress' do
      ledger = new_ledger
      described_class.mark_sent!(ledger, payload_hash: 'abc')

      expect(described_class.claim_ledger(ledger)).to be(false)
      expect(ledger.reload.status).to eq('sent')
    end

    it 'claims a sent row once it is stale' do
      ledger = new_ledger
      described_class.mark_sent!(ledger, payload_hash: 'abc')
      ledger.update_columns(sent_at: 16.minutes.ago)

      expect(described_class.claim_ledger(ledger)).to be(true)
    end

    it 'claims an acknowledged row so edits after a send are streamed' do
      ledger = new_ledger
      described_class.mark_acknowledged!(ledger, response_code: 200)

      expect(described_class.claim_ledger(ledger)).to be(true)
    end

    it 'never claims a dead row' do
      ledger = new_ledger
      described_class.mark_failed!(ledger, error_message: 'bad payload', response_code: 422, permanent: true)

      expect(described_class.claim_ledger(ledger)).to be(false)
      expect(ledger.reload.status).to eq('dead')
    end

    it 'lets only one of two stale copies of the same row win' do
      first_copy = new_ledger
      second_copy = StreamingLedger.find(first_copy.id)

      results = [described_class.claim_ledger(first_copy), described_class.claim_ledger(second_copy)]

      expect(results).to contain_exactly(true, false)
    end
  end

  describe '.record_failure!' do
    it 'never makes a row dead for transient errors, however many attempts' do
      ledger = new_ledger
      ledger.update_columns(retry_count: 500)

      described_class.record_failure!(ledger, error_message: 'connection refused')

      expect(ledger.reload.status).to eq('retrying')
      expect(ledger.next_attempt_at).to be <= Time.current + 6.hours + (6.hours * 0.2) + 1.second
    end

    it 'makes a row dead immediately for a permanent error' do
      ledger = new_ledger

      described_class.record_failure!(ledger, error_message: 'unprocessable', response_code: 422, permanent: true)

      expect(ledger.reload.status).to eq('dead')
      expect(ledger.next_attempt_at).to be_nil
    end

    it 'makes a row dead after max_attempts unclassified errors' do
      ledger = new_ledger
      ledger.update_columns(retry_count: ledger.max_attempts - 1)

      described_class.record_failure!(ledger, error_message: 'NoMethodError', transient: false)

      expect(ledger.reload.status).to eq('dead')
    end

    it 'keeps retrying an unclassified error below max_attempts' do
      ledger = new_ledger

      described_class.record_failure!(ledger, error_message: 'NoMethodError', transient: false)

      expect(ledger.reload.status).to eq('retrying')
    end
  end

  describe '.release_stale_claims!' do
    it 'returns an abandoned claim to retrying without killing it' do
      ledger = new_ledger
      described_class.claim_ledger(ledger)
      ledger.update_columns(locked_at: 16.minutes.ago, retry_count: 500)

      described_class.release_stale_claims!

      expect(ledger.reload.status).to eq('retrying')
    end
  end

  describe '.reserve_for_drain' do
    it 'hides a due row from the next drain run without changing its status' do
      ledger = new_ledger

      expect(described_class.reserve_for_drain(ledger)).to be(true)
      expect(ledger.reload.status).to eq('queued')
      expect(described_class.due_streams(limit: 10)).not_to include(ledger)
      expect(described_class.deferred?(ledger)).to be(true)
      expect(described_class.claim_ledger(ledger)).to be(true)
    end

    it 'reserves a row only once' do
      ledger = new_ledger

      expect(described_class.reserve_for_drain(ledger)).to be(true)
      expect(described_class.reserve_for_drain(StreamingLedger.find(ledger.id))).to be(false)
    end
  end

  describe '.reset_dead!' do
    it 'returns a dead row to queued with a fresh attempt budget' do
      ledger = new_ledger
      described_class.mark_failed!(ledger, error_message: 'bad', response_code: 422, permanent: true)

      expect(described_class.reset_dead!(ledger)).to be(true)
      expect(ledger.reload.status).to eq('queued')
      expect(ledger.retry_count).to eq(0)
      expect(described_class.reset_dead!(ledger)).to be(false)
    end
  end
end
