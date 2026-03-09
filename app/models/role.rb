class Role < ApplicationRecord
  acts_as_tenant :company

  STATUSES = %w[draft published internal_only closed].freeze

  # Allowed state transitions: current_status => [allowed_next_statuses]
  TRANSITIONS = {
    "draft" => %w[published internal_only],
    "published" => %w[internal_only closed draft],
    "internal_only" => %w[published closed draft],
    "closed" => %w[draft]
  }.freeze

  belongs_to :company
  has_many :interview_phases, -> { order(position: :asc) }, dependent: :destroy
  has_many :active_interview_phases, -> { active.order(position: :asc) }, class_name: "InterviewPhase"
  has_many :applications, class_name: "ApplicationSubmission", dependent: :destroy
  has_many :candidates, through: :applications
  has_many :custom_questions, -> { order(position: :asc) }, dependent: :destroy
  has_many :status_transitions, class_name: "RoleStatusTransition", dependent: :destroy
  has_many :transfer_markers_as_source, class_name: "TransferMarker", foreign_key: :source_role_id, dependent: :destroy
  has_many :transfer_markers_as_target, class_name: "TransferMarker", foreign_key: :target_role_id, dependent: :destroy
  belongs_to :hiring_manager, -> { unscope(where: :discarded_at) }, class_name: "User", optional: true
  has_rich_text :description

  before_validation :generate_slug, if: -> { slug.blank? || title_changed? }
  after_create :seed_default_interview_phases

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: {scope: :company_id}
  validates :status, presence: true, inclusion: {in: STATUSES}
  validates :salary_min, numericality: {only_integer: true, greater_than_or_equal_to: 0}, allow_nil: true
  validates :salary_max, numericality: {only_integer: true, greater_than_or_equal_to: 0}, allow_nil: true
  validate :salary_max_greater_than_or_equal_to_min

  scope :published, -> { where(status: "published") }
  scope :draft, -> { where(status: "draft") }
  scope :internal_only, -> { where(status: "internal_only") }
  scope :closed, -> { where(status: "closed") }
  # Publicly visible roles: only published roles are shown to unauthenticated visitors.
  # Draft, internal_only, and closed roles return 404 for public requests.
  scope :publicly_visible, -> { published }

  # --- Preview Token ---

  # Generates a secure preview token for sharing draft roles.
  # Returns the token string and persists it on the record.
  def generate_preview_token!
    token = SecureRandom.urlsafe_base64(32)
    update!(preview_token: token)
    token
  end

  # Regenerates the preview token, invalidating any previous links.
  def regenerate_preview_token!
    generate_preview_token!
  end

  # Revokes the current preview token.
  def revoke_preview_token!
    update!(preview_token: nil)
  end

  # Returns true if the given token matches this role's preview token.
  def valid_preview_token?(token)
    preview_token.present? && ActiveSupport::SecurityUtils.secure_compare(preview_token, token.to_s)
  end

  def draft?
    status == "draft"
  end

  def published?
    status == "published"
  end

  def internal_only?
    status == "internal_only"
  end

  def closed?
    status == "closed"
  end

  # --- State transition guards ---

  def can_transition_to?(new_status)
    TRANSITIONS.fetch(status, []).include?(new_status.to_s)
  end

  def can_publish?
    can_transition_to?("published") && publishable?
  end

  # Returns true if the role has at least one active interview phase with a phase owner assigned.
  # This is a prerequisite for publishing.
  def publishable?
    active_interview_phases.where.not(phase_owner_id: nil).exists?
  end

  def can_make_internal_only?
    can_transition_to?("internal_only")
  end

  def can_close?
    can_transition_to?("closed")
  end

  # --- State transition methods ---

  def transition_to!(new_status, user: nil)
    new_status = new_status.to_s
    unless can_transition_to?(new_status)
      errors.add(:status, "cannot transition from #{status} to #{new_status}")
      raise ActiveRecord::RecordInvalid, self
    end
    if new_status == "published" && !publishable?
      errors.add(:base, "Cannot publish: at least one interview phase must have a phase owner assigned")
      raise ActiveRecord::RecordInvalid, self
    end

    old_status = status
    transaction do
      update!(status: new_status)
      status_transitions.create!(
        from_status: old_status,
        to_status: new_status,
        user: user,
        company: company
      )
    end
  end

  def publish!(user: nil)
    transition_to!("published", user: user)
  end

  def make_internal_only!(user: nil)
    transition_to!("internal_only", user: user)
  end

  def close!(user: nil)
    transition_to!("closed", user: user)
  end

  def transition_history
    status_transitions.reverse_chronological.includes(:user)
  end

  def last_transition
    status_transitions.reverse_chronological.first
  end

  def salary_range
    return nil if salary_min.blank? && salary_max.blank?

    currency = salary_currency || "USD"
    if salary_min.present? && salary_max.present?
      "#{currency} #{salary_min.to_fs(:delimited)}–#{salary_max.to_fs(:delimited)}"
    elsif salary_min.present?
      "#{currency} #{salary_min.to_fs(:delimited)}+"
    else
      "Up to #{currency} #{salary_max.to_fs(:delimited)}"
    end
  end

  private

  def generate_slug
    return if title.blank?

    base_slug = title.parameterize
    candidate_slug = base_slug
    counter = 1

    # Ensure uniqueness within the company scope
    while Role.where(company_id: company_id).where.not(id: id).exists?(slug: candidate_slug)
      counter += 1
      candidate_slug = "#{base_slug}-#{counter}"
    end

    self.slug = candidate_slug
  end

  def seed_default_interview_phases
    InterviewPhase::DEFAULT_PHASES.each_with_index do |phase_name, index|
      interview_phases.create!(name: phase_name, position: index, company: company)
    end
  end

  def salary_max_greater_than_or_equal_to_min
    return if salary_min.blank? || salary_max.blank?

    if salary_max < salary_min
      errors.add(:salary_max, "must be greater than or equal to minimum salary")
    end
  end
end
