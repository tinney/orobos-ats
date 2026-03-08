class OfferRevision < ApplicationRecord
  belongs_to :offer
  belongs_to :changed_by, class_name: "User", optional: true
end
