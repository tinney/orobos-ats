class OfferRevision < ApplicationRecord
  belongs_to :offer
  belongs_to :changed_by, -> { unscope(where: :discarded_at) }, class_name: "User", optional: true
end
