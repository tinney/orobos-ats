class Scorecard < ApplicationRecord
  acts_as_tenant :company
  belongs_to :company
  belongs_to :interview
  belongs_to :user
  has_many :scorecard_categories, dependent: :destroy

  accepts_nested_attributes_for :scorecard_categories, allow_destroy: true

  validates :user_id, uniqueness: { scope: :interview_id }

  def average_rating
    return nil if scorecard_categories.empty?
    scorecard_categories.average(:rating)&.round(1)
  end
end
