# frozen_string_literal: true

# model for LIMS acknowledgement statuses
class LimsAcknowledgementStatus < VoidableRecord
  self.table_name = :lims_acknowledgement_statuses
  self.primary_keys = %i[order_id test]

  belongs_to :order, foreign_key: :order_id, optional: true
end
