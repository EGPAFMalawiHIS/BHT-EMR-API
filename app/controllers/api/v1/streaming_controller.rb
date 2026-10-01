# frozen_string_literal: true

module Api
  module V1
    class StreamingController < ApplicationController
      REPLAY_BATCH_LIMIT = 100

      def failed
        render json: SolidQueue::FailedExecution.all.as_json(include: :job)
      end

      def index
        ledgers = StreamingLedgerService.query(
          status: params[:status],
          start_date: params[:start_date],
          end_date: params[:end_date],
          patient_id: params[:patient_id],
          program_id: params[:program_id],
          stream_key: params[:stream_key]
        )

        render json: ledgers.as_json(
          only: %i[
            id uuid stream_key patient_id program_id stream_date status
            payload_hash response_code error_message next_attempt_at
            sent_at acknowledged_at retry_count created_at updated_at
          ]
        )
      rescue ArgumentError => e
        render json: { error: e.message }, status: :bad_request
      end

      def stats
        ledger_stats = StreamingLedger.group(:status).count
        outstanding = StreamingLedger.where.not(status: %w[acknowledged dead])
        last_successful_sync = StreamingLedger
                               .where(status: 'acknowledged')
                               .maximum(:acknowledged_at)

        render json: {
          ledger: {
            by_status: ledger_stats,
            outstanding: outstanding.count,
            oldest_outstanding: outstanding.minimum(:created_at),
            last_successful_sync:,
            dead_count: ledger_stats['dead'] || 0
          },
          queue: {
            ready: SolidQueue::ReadyExecution.count,
            scheduled: SolidQueue::ScheduledExecution.count,
            claimed: SolidQueue::ClaimedExecution.count,
            failed: SolidQueue::FailedExecution.count
          }
        }
      end

      def ack
        stream_key = params[:stream_key].presence || params[:id].presence
        return render json: { error: 'stream_key is required' }, status: :bad_request if stream_key.blank?

        ledger = StreamingLedgerService.find_by_stream_key(stream_key)
        return render json: { error: 'stream not found' }, status: :not_found unless ledger

        StreamingLedgerService.mark_acknowledged!(ledger, response_code: params[:response_code].presence)

        render json: {
          stream_key: ledger.stream_key,
          status: ledger.reload.status,
          acknowledged_at: ledger.acknowledged_at,
          response_code: ledger.response_code
        }
      end

      # Manual escape hatch. The scheduled drain handles everything except
      # `dead` rows, which only an operator can retry; that is why a dead row is
      # accepted here and its attempt counter is reset.
      def replay
        stream_key = params[:stream_key].presence
        ledgers = if stream_key.present?
                    ledger = StreamingLedgerService.find_by_stream_key(stream_key)
                    return render json: { error: 'stream not found' }, status: :not_found unless ledger

                    [ledger]
                  else
                    StreamingLedger
                      .where(status: %w[queued failed retrying dead])
                      .order(:updated_at)
                      .limit(REPLAY_BATCH_LIMIT)
                      .to_a
                  end

        enqueued = []
        ledgers.each do |ledger|
          next if ledger.acknowledged?
          # A worker already owns it; a second job would only lose the claim.
          next if StreamingLedgerService.in_flight?(ledger)
          # Dead rows get a fresh attempt budget. If the reset loses a race
          # with another replay call, that call has already enqueued it.
          next if ledger.dead? && !StreamingLedgerService.reset_dead!(ledger)

          StreamingJob.perform_later(
            patient_id: ledger.patient_id,
            program_id: ledger.program_id,
            date: ledger.stream_date.to_s
          )
          enqueued << ledger.stream_key
        end

        render json: {
          queued: enqueued,
          count: enqueued.count
        }
      end
    end
  end
end
