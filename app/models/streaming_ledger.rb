# frozen_string_literal: true

class StreamingLedger < ApplicationRecord
  enum :status, {
    queued: 'queued',
    sending: 'sending',
    sent: 'sent',
    acknowledged: 'acknowledged',
    failed: 'failed',
    retrying: 'retrying',
    dead: 'dead'
  }, validate: true

  validates :stream_key, :patient_id, :program_id, :stream_date, presence: true

  before_validation :set_stream_key, on: :create
  before_validation :set_uuid, on: :create

  def set_stream_key
    return if stream_key.present?
    return unless patient_id.present? && program_id.present? && stream_date.present?

    location_id = Location.current_health_center&.id
    self.stream_key = [location_id, patient_id, program_id, stream_date.iso8601].join(':')
  end

  def set_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def self.next_delay(retry_count)
    base = [60 * (2**retry_count), 6.hours.to_i].min
    base + rand(0..(base * 0.2)).to_i
  end
end
