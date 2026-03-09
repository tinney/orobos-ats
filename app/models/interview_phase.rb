class InterviewPhase < ApplicationRecord
  acts_as_tenant :company

  DEFAULT_PHASES = [
    "Phone Screen",
    "Technical Interview",
    "Onsite Interview",
    "Final Interview"
  ].freeze

  # When true, skips auto-assignment of position on create
  attr_accessor :explicit_position

  belongs_to :company
  belongs_to :role
  belongs_to :phase_owner, -> { unscope(where: :discarded_at) }, class_name: "User", optional: true
  belongs_to :original_phase, class_name: "InterviewPhase", optional: true
  belongs_to :scorecard_template, class_name: "ScorecardsTemplate", optional: true
  has_many :versions, class_name: "InterviewPhase", foreign_key: :original_phase_id, dependent: :nullify
  has_many :candidate_interviews, class_name: "Interview", dependent: :destroy

  validates :name, presence: true
  validate :name_unique_among_active_phases, unless: :archived?
  validates :position, presence: true,
    numericality: {only_integer: true, greater_than_or_equal_to: 0}
  validates :phase_version, presence: true,
    numericality: {only_integer: true, greater_than_or_equal_to: 1}

  scope :ordered, -> { order(position: :asc) }
  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  before_validation :set_default_position, on: :create

  def archived?
    archived_at.present?
  end

  def active?
    !archived?
  end

  def archive!
    update!(archived_at: Time.current)
  end

  # Check if this phase has any associated interview data (interviews/scorecards).
  def has_candidate_data?
    candidate_interviews.exists?
  end

  # Returns the root phase ID for this version lineage
  def root_phase_id
    original_phase_id || id
  end

  # Returns the latest active version in this phase's lineage
  def latest_active_version
    self.class.where(
      "id = :root OR original_phase_id = :root", root: root_phase_id
    ).active.order(phase_version: :desc).first
  end

  # Check if this phase is part of a version lineage
  def versioned?
    original_phase_id.present? || versions.exists?
  end

  # Update phase attributes with versioning support.
  # If the phase has candidate data, archives the current version and creates
  # a new version with updated attributes, preserving historical records.
  # If no candidate data exists, updates in place.
  #
  # Returns the (possibly new) active phase.
  def update_with_versioning(attributes)
    if has_candidate_data?
      create_new_version(attributes)
    else
      update!(attributes)
      self
    end
  end

  # Create a new version of this phase, archiving the current one.
  # The new version inherits the role, company, and phase_owner, with incremented version number.
  #
  # Existing interviews and scorecards remain linked to the archived phase,
  # preserving historical data against the original phase configuration.
  #
  # Applications whose current_interview_phase_id points to this phase and
  # do NOT have interviews for it are migrated to the new version.
  # Applications that DO have interviews keep their reference to the archived phase
  # (their interview data is already preserved there).
  #
  # Returns the new active phase.
  def create_new_version(attributes = {})
    transaction do
      lineage_root_id = original_phase_id || id
      next_version = self.class.where(
        "id = :root OR original_phase_id = :root", root: lineage_root_id
      ).maximum(:phase_version).to_i + 1

      archive!

      new_phase = self.class.new(
        company: company,
        role: role,
        name: attributes.fetch(:name, name),
        position: attributes.fetch(:position, position),
        phase_owner_id: attributes.fetch(:phase_owner_id, phase_owner_id),
        scorecard_template_id: attributes.fetch(:scorecard_template_id, scorecard_template_id),
        original_phase_id: lineage_root_id,
        phase_version: next_version
      )
      new_phase.explicit_position = true
      new_phase.save!

      # Migrate applications that are "at" this phase but have no interviews yet.
      # Applications with existing interviews keep their reference to the archived
      # phase so their scorecard and interview data is preserved intact.
      migrate_applications_to_new_version(new_phase)

      new_phase
    end
  end

  # Move this phase to a specific position, reordering siblings accordingly.
  # Position is clamped to valid bounds [0, max_sibling_count].
  def move_to(new_position)
    return if new_position == position

    siblings = role.interview_phases.active.where.not(id: id).order(position: :asc).to_a
    # Clamp to valid range
    new_position = [[new_position, 0].max, siblings.length].min
    siblings.insert(new_position, self)
    siblings.each_with_index do |phase, index|
      phase.update_column(:position, index) if phase.position != index
    end
    reload
  end

  # Recompact positions for all active phases of this role to be sequential from 0.
  # Useful after deletion or archival to maintain gap-free ordering.
  def self.recompact_positions!(role)
    role.interview_phases.active.order(position: :asc).each_with_index do |phase, index|
      phase.update_column(:position, index) if phase.position != index
    end
  end

  # Returns the full version history for this phase lineage
  def version_history
    root_id = original_phase_id || id
    self.class.unscoped.where(
      "id = :root OR original_phase_id = :root", root: root_id
    ).order(phase_version: :asc)
  end

  private

  # Migrate applications pointing to this phase to the new version,
  # but only if they don't have interview data for this phase.
  # Applications WITH interview data keep their reference to preserve
  # the historical scorecard/feedback linkage.
  def migrate_applications_to_new_version(new_phase)
    return unless defined?(ApplicationSubmission)

    applications_at_phase = ApplicationSubmission.where(current_interview_phase_id: id)
    applications_at_phase.find_each do |app|
      has_interview_for_phase = app.interviews.where(interview_phase_id: id).exists?
      unless has_interview_for_phase
        app.update_column(:current_interview_phase_id, new_phase.id)
      end
    end
  end

  def name_unique_among_active_phases
    return if name.blank? || role_id.blank?

    scope = self.class.where(role_id: role_id, name: name).active
    scope = scope.where.not(id: id) if persisted?
    if scope.exists?
      errors.add(:name, "already exists for this role")
    end
  end

  def set_default_position
    return if explicit_position
    return if position.present? && position > 0

    max_position = role&.interview_phases&.active&.maximum(:position)
    self.position = max_position ? max_position + 1 : 0
  end
end
