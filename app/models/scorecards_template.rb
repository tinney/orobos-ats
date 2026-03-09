class ScorecardsTemplate < ApplicationRecord
  acts_as_tenant :company

  belongs_to :company
  has_many :scorecard_template_categories, dependent: :destroy
  has_many :interview_phases, foreign_key: :scorecard_template_id, dependent: :nullify

  validates :name, presence: true,
    uniqueness: {scope: :company_id, message: "already exists"}

  accepts_nested_attributes_for :scorecard_template_categories, allow_destroy: true,
    reject_if: proc { |attrs| attrs["name"].blank? }

  # Build scorecard categories from this template's categories
  def build_scorecard_categories(scorecard)
    scorecard_template_categories.ordered.each do |tc|
      scorecard.scorecard_categories.build(name: tc.name)
    end
  end
end
