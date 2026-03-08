class CustomQuestion < ApplicationRecord
  acts_as_tenant :company
  belongs_to :company
  belongs_to :role
  has_many :question_snapshots, dependent: :nullify

  validates :label, presence: true
  validates :field_type, presence: true, inclusion: { in: %w[text textarea select] }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(position: :asc) }
end
