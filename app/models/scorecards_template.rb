class ScorecardsTemplate < ApplicationRecord
  acts_as_tenant :company

  belongs_to :company
  belongs_to :interview_phase
  has_many :scorecard_template_categories, dependent: :destroy

  validates :name, presence: true,
    uniqueness: { scope: :interview_phase_id, message: "already exists for this interview phase" }
  validates :interview_phase_id, presence: true

  accepts_nested_attributes_for :scorecard_template_categories, allow_destroy: true
end
