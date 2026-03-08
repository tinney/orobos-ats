class Interview < ApplicationRecord
  acts_as_tenant :company

  STATUSES = %w[unscheduled scheduled complete cancelled].freeze

  # Valid state transitions:
  # unscheduled -> scheduled, cancelled
  # scheduled   -> complete, cancelled, unscheduled (reschedule back to unscheduled)
  # complete    -> (terminal state, no transitions out)
  # cancelled   -> unscheduled (reopen)
  VALID_TRANSITIONS = {
    "unscheduled" => %w[scheduled cancelled],
    "scheduled"   => %w[complete cancelled unscheduled],
    "complete"    => [],
    "cancelled"   => %w[unscheduled]
  }.freeze

  belongs_to :company
  belongs_to :application, class_name: "ApplicationSubmission", foreign_key: :application_id
  belongs_to :interview_phase
  has_many :interview_participants, dependent: :destroy
  has_many :interviewers, through: :interview_participants, source: :user
  has_many :panel_interviews, dependent: :delete_all
  has_many :panel_members, through: :panel_interviews, source: :user
  has_many :scorecards, dependent: :destroy

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :application_id, uniqueness: {
    scope: :interview_phase_id,
    message: "already has an interview for this phase"
  }
  validates :scheduled_at, presence: true, if: -> { status == "scheduled" }
  validates :duration_minutes, numericality: { greater_than: 0, allow_nil: true }
  validate :validate_status_transition, if: :status_changed?

  scope :scheduled, -> { where(status: "scheduled") }
  scope :unscheduled, -> { where(status: "unscheduled") }
  scope :complete, -> { where(status: "complete") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :active, -> { where(status: %w[unscheduled scheduled]) }

  # Fetches all interviews assigned to a user as either an interviewer
  # (via interview_participants) or a panel member (via panel_interviews).
  # Eager-loads application (with candidate and role), interview_phase, and participants.
  scope :for_user, ->(user) {
    participant_ids = InterviewParticipant.where(user_id: user.id).select(:interview_id)
    panel_ids = PanelInterview.where(user_id: user.id).select(:interview_id)

    where(id: participant_ids)
      .or(where(id: panel_ids))
      .includes(
        application: [:candidate, :role],
        interview_phase: [],
        interview_participants: :user,
        panel_interviews: :user
      )
      .order(Arel.sql("CASE status WHEN 'scheduled' THEN 0 WHEN 'unscheduled' THEN 1 WHEN 'complete' THEN 2 ELSE 3 END, scheduled_at ASC NULLS LAST"))
  }

  # Eager-loaded version for dashboard listing with all related data
  scope :with_full_details, -> {
    includes(
      application: [:candidate, :role],
      interview_phase: [],
      interview_participants: :user,
      panel_interviews: :user,
      scorecards: []
    )
  }

  def scheduled?; status == "scheduled"; end
  def unscheduled?; status == "unscheduled"; end
  def complete?; status == "complete"; end
  def cancelled?; status == "cancelled"; end
  def terminal?; complete?; end
  def active?; unscheduled? || scheduled?; end

  def can_transition_to?(new_status)
    VALID_TRANSITIONS.fetch(status, []).include?(new_status.to_s)
  end

  def transition_to!(new_status)
    unless can_transition_to?(new_status)
      raise InvalidTransitionError, "Cannot transition from '#{status}' to '#{new_status}'"
    end
    self.status = new_status.to_s
    save!
  end

  def schedule!(time, duration: nil, location: nil)
    raise InvalidTransitionError, "Cannot schedule from '#{status}'" unless can_transition_to?("scheduled")

    attrs = { scheduled_at: time, status: "scheduled" }
    attrs[:duration_minutes] = duration if duration
    attrs[:location] = location if location
    update!(attrs)
  end

  def complete!
    raise InvalidTransitionError, "Cannot complete from '#{status}'" unless can_transition_to?("complete")
    update!(status: "complete", completed_at: Time.current)
  end

  def cancel!(reason: nil)
    raise InvalidTransitionError, "Cannot cancel from '#{status}'" unless can_transition_to?("cancelled")
    update!(status: "cancelled", cancelled_at: Time.current, cancelled_reason: reason)
  end

  def reopen!
    raise InvalidTransitionError, "Cannot reopen from '#{status}'" unless can_transition_to?("unscheduled")
    update!(status: "unscheduled", scheduled_at: nil, completed_at: nil, cancelled_at: nil, cancelled_reason: nil)
  end

  def reschedule!(time, reason: nil)
    raise InvalidTransitionError, "Cannot reschedule from '#{status}'" unless status == "scheduled"

    history_entry = {
      "from" => scheduled_at&.iso8601,
      "to" => time.iso8601,
      "reason" => reason,
      "at" => Time.current.iso8601
    }
    update!(
      scheduled_at: time,
      reschedule_count: (reschedule_count || 0) + 1,
      reschedule_reason: reason,
      schedule_history: (schedule_history || []) + [history_entry]
    )
  end

  def panel_member?(user)
    return false unless user
    interview_participants.exists?(user_id: user.id)
  end

  def assign_interviewer!(user)
    interview_participants.find_or_create_by!(user: user)
  end

  def remove_interviewer!(user)
    interview_participants.find_by!(user: user).destroy!
  end

  def add_panel_member!(user)
    panel_interviews.find_or_create_by!(user: user)
  end

  def remove_panel_member!(user)
    panel_interviews.find_by!(user: user).destroy!
  end

  def has_panel_members?
    panel_interviews.exists?
  end

  class InvalidTransitionError < StandardError; end

  private

  def validate_status_transition
    return if new_record? # Allow any initial status on creation
    return unless status_was.present?

    allowed = VALID_TRANSITIONS.fetch(status_was, [])
    unless allowed.include?(status)
      errors.add(:status, "cannot transition from '#{status_was}' to '#{status}'")
    end
  end
end
