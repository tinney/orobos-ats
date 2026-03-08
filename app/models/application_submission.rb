class ApplicationSubmission < ApplicationRecord
  self.table_name = "applications"

  acts_as_tenant :company

  STATUSES = %w[applied interviewing on_hold rejected accepted withdrawn].freeze
  TERMINAL_STATUSES = %w[rejected accepted withdrawn].freeze
  ACTIVE_STATUSES = %w[applied interviewing on_hold].freeze

  REJECTION_REASONS = [
    "Not enough experience",
    "Skills mismatch",
    "Culture fit concerns",
    "Position filled",
    "Overqualified",
    "Failed technical assessment",
    "No show",
    "Other"
  ].freeze

  WITHDRAWAL_REASONS = [
    "Accepted another offer",
    "Compensation expectations not met",
    "Role not as described",
    "Personal reasons",
    "Relocation concerns",
    "Timeline too long",
    "Other"
  ].freeze

  belongs_to :company
  belongs_to :candidate
  belongs_to :role
  belongs_to :current_interview_phase, class_name: "InterviewPhase", optional: true
  has_many :interviews, foreign_key: :application_id, dependent: :destroy
  has_many :question_snapshots, foreign_key: :application_id, dependent: :destroy
  has_many :offers, foreign_key: :offer_application_id, dependent: :destroy
  has_one_attached :resume

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :candidate_id, uniqueness: { scope: :role_id, message: "has already applied for this role" }
  validates :rejection_reason, inclusion: { in: REJECTION_REASONS }, allow_blank: true
  validates :withdrawal_reason, inclusion: { in: WITHDRAWAL_REASONS }, allow_blank: true
  validate :resume_format, if: -> { resume.attached? }

  scope :active, -> { where(status: ACTIVE_STATUSES) }
  scope :by_status, ->(status) { where(status: status) }
  scope :bot_flagged, -> { where(bot_flagged: true, bot_dismissed: false) }
  scope :not_bot_flagged, -> { where(bot_flagged: false).or(where(bot_dismissed: true)) }

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  # Pipeline transitions
  def advance_to!(new_status, reason: nil)
    self.previous_status = status
    self.status = new_status
    self.rejection_reason = reason if new_status == "rejected"
    self.withdrawal_reason = reason if new_status == "withdrawn"
    save!
  end

  def reject!(reason:)
    advance_to!("rejected", reason: reason)
  end

  def withdraw!(reason:)
    advance_to!("withdrawn", reason: reason)
  end

  def accept!
    advance_to!("accepted")
  end

  def put_on_hold!
    advance_to!("on_hold")
  end

  def start_interviewing!
    advance_to!("interviewing")
  end

  def reopen!
    return unless terminal?
    restore_status = previous_status.presence || "applied"
    restore_status = "applied" if TERMINAL_STATUSES.include?(restore_status)
    self.previous_status = status
    self.status = restore_status
    self.rejection_reason = nil
    self.withdrawal_reason = nil
    save!
  end

  def dismiss_bot_flag!
    update!(bot_dismissed: true)
  end

  def bot_warning?
    bot_flagged? && !bot_dismissed?
  end

  # Linked applications: same candidate email, same tenant, different role
  def linked_applications
    ApplicationSubmission.where(candidate_id: candidate_id).where.not(id: id)
  end

  def linked_application_count
    linked_applications.count
  end

  # Percent complete: interviews completed / total phases
  def percent_complete
    total_phases = role.active_interview_phases.count
    return 0 if total_phases.zero?
    completed = interviews.where(status: "complete").count
    ((completed.to_f / total_phases) * 100).round
  end

  # Transfer to another role
  def transfer_to!(target_role)
    transaction do
      # Create transfer marker in source
      TransferMarker.create!(
        source_role: role,
        target_role: target_role,
        candidate: candidate,
        company: company,
        transferred_at: Time.current
      )

      # Create new application in target role
      new_app = ApplicationSubmission.create!(
        candidate: candidate,
        role: target_role,
        company: company,
        status: "applied",
        transferred_from_role_id: role.id,
        transferred_at: Time.current
      )

      # Update transfer marker with target application
      TransferMarker.where(
        source_role: role,
        candidate: candidate,
        company: company
      ).last.update!(target_application_id: new_app.id)

      # Wipe interview and offer data from this application
      interviews.destroy_all
      offers.destroy_all
      update!(current_interview_phase_id: nil)

      new_app
    end
  end

  private

  def resume_format
    unless resume.content_type.in?(%w[application/pdf application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document])
      errors.add(:resume, "must be a PDF or Word document")
    end
    if resume.blob.byte_size > 10.megabytes
      errors.add(:resume, "must be less than 10 MB")
    end
  end

  public

  # Hard delete - true no-trace deletion
  def hard_delete!
    transaction do
      question_snapshots.destroy_all
      interviews.destroy_all
      offers.destroy_all
      resume.purge if resume.attached?
      destroy!
    end
  end
end
