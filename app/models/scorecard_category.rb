class ScorecardCategory < ApplicationRecord
  belongs_to :scorecard
  validates :name, presence: true, uniqueness: { scope: :scorecard_id }
  validates :rating, presence: true, inclusion: { in: 1..5 }
end
