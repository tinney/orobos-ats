class TransferMarker < ApplicationRecord
  acts_as_tenant :company
  belongs_to :company
  belongs_to :source_role, class_name: "Role"
  belongs_to :target_role, class_name: "Role"
  belongs_to :candidate
  belongs_to :target_application, class_name: "ApplicationSubmission", foreign_key: :target_application_id, optional: true

  validates :transferred_at, presence: true
end
