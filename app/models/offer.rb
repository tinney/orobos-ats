class Offer < ApplicationRecord
  acts_as_tenant :company
  belongs_to :company
  belongs_to :application_submission, foreign_key: :offer_application_id, class_name: "ApplicationSubmission"
  belongs_to :created_by, -> { unscope(where: :discarded_at) }, class_name: "User"
  has_many :offer_revisions, dependent: :destroy

  STATUSES = %w[pending accepted declined revoked].freeze
  validates :status, presence: true, inclusion: {in: STATUSES}
  validates :salary, numericality: {greater_than: 0}, allow_nil: true
  validates :revision, presence: true, numericality: {only_integer: true, greater_than_or_equal_to: 1}

  before_update :save_revision_history

  def pending?
    status == "pending"
  end

  def accepted?
    status == "accepted"
  end

  def declined?
    status == "declined"
  end

  def revoked?
    status == "revoked"
  end

  private

  def save_revision_history
    return unless changed?
    offer_revisions.create!(
      salary: salary_was,
      salary_currency: salary_currency_was,
      start_date: start_date_was,
      status: status_was,
      notes: notes_was,
      revision_number: revision,
      changed_by_id: created_by_id
    )
    self.revision += 1
  end
end
