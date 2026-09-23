# frozen_string_literal: true

module Api
  module V1
    class StreamingController < ApplicationController
      skip_before_action :authenticate
      before_action :ensure_streaming_enabled

      def failed
        render json: SolidQueue::FailedExecution.all.as_json(include: :job)
      rescue ActiveRecord::StatementInvalid => e
        render_streaming_unavailable(e.message)
      end

      def stats
        jobs_done = SolidQueue::ClaimedExecution.count
        jobs_failed = SolidQueue::FailedExecution.count
        jobs_pending = SolidQueue::ReadyExecution.count
        jobs_queued = SolidQueue::ScheduledExecution.count
        last_sync_at = SolidQueue::ClaimedExecution.maximum(:created_at)
        visits_since_last_sync = Encounter.all.where(program_id: 1, encounter_datetime: last_sync_at..).group(:patient_id).count

        render json: {
          solid_queue: {
            jobs_done:,
            jobs_failed:,
            jobs_pending:,
            jobs_queued:
          },
          last_sync_at:,
          visits_since_last_sync:
        }
      rescue ActiveRecord::StatementInvalid => e
        render_streaming_unavailable(e.message)
      end

      private

      def ensure_streaming_enabled
        return if streaming_enabled?

        render json: {
          error: 'Streaming is disabled. Set ENABLE_STREAMING=true and run rails streaming:enable.'
        }, status: :service_unavailable
      end

      def streaming_enabled?
        StreamingSettings.enabled?
      end

      def render_streaming_unavailable(details)
        render json: {
          error: 'Streaming queue is not available. Run rails streaming:enable to provision queue tables.',
          details:
        }, status: :service_unavailable
      end
    end
  end
end