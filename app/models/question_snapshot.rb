class QuestionSnapshot < ApplicationRecord
  acts_as_tenant :company
  belongs_to :company
  belongs_to :application_submission, foreign_key: :application_id, class_name: "ApplicationSubmission"
  belongs_to :custom_question, optional: true

  validates :label, presence: true
  validates :field_type, presence: true
end
