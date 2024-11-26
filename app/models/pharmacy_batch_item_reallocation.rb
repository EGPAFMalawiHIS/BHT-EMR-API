# frozen_string_literal: true

class PharmacyBatchItemReallocation < VoidableRecord
  self.primary_key = %i[id  site_id]

  belongs_to :item, class_name: 'PharmacyBatchItem', foreign_key: [:batch_item_id, :site_id]
  belongs_to :location, optional: true
end
