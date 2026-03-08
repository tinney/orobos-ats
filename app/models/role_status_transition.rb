class RoleStatusTransition < ApplicationRecord
  acts_as_tenant :company

  belongs_to :company
  belongs_to :role
  belongs_to :user, optional: true

  validates :from_status, presence: true, inclusion: { in: Role::STATUSES }
  validates :to_status, presence: true, inclusion: { in: Role::STATUSES }
  validate :statuses_differ

  scope :chronological, -> { order(created_at: :asc) }
  scope :reverse_chronological, -> { order(created_at: :desc) }

  private

  def statuses_differ
    if from_status == to_status
      errors.add(:to_status, "must differ from the current status")
    end
  end
end
