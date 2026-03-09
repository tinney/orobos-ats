class ScorecardTemplateCategory < ApplicationRecord
  belongs_to :scorecards_template

  validates :name, presence: true,
    uniqueness: {scope: :scorecards_template_id, message: "already exists for this template"}
  validates :sort_order, presence: true,
    numericality: {only_integer: true, greater_than_or_equal_to: 0}

  scope :ordered, -> { order(sort_order: :asc) }
end
