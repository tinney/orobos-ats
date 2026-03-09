class User < ApplicationRecord
  acts_as_tenant :company

  ROLES = %w[admin hiring_manager interviewer].freeze
  MAGIC_LINK_TOKEN_EXPIRY = 15.minutes
  SESSION_DURATION = 30.days

  belongs_to :company
  has_many :interview_participants, dependent: :destroy
  has_many :interviews, through: :interview_participants
  has_many :panel_interviews, dependent: :delete_all
  has_many :panel_assigned_interviews, through: :panel_interviews, source: :interview

  validates :email, presence: true,
    uniqueness: {case_sensitive: false},
    format: {with: URI::MailTo::EMAIL_REGEXP}
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :role, presence: true, inclusion: {in: ROLES}
  validates :time_zone, presence: true,
    inclusion: {in: ->(_) { ActiveSupport::TimeZone::MAPPING.keys },
                message: "is not a recognized timezone"}
  validate :must_retain_at_least_one_admin, if: :role_changed?

  before_validation :normalize_email

  # Default scope: soft-deleted users are excluded from all queries by default.
  default_scope { where(discarded_at: nil) }

  scope :active, -> { where(discarded_at: nil) }
  scope :discarded, -> { unscope(where: :discarded_at).where.not(discarded_at: nil) }

  # Class method to query including soft-deleted records
  def self.with_discarded
    unscope(where: :discarded_at)
  end

  # Class method to query only soft-deleted records
  def self.only_discarded
    unscope(where: :discarded_at).where.not(discarded_at: nil)
  end

  # --- Magic link token management ---

  # Generates a secure magic link token, stores its digest on the user,
  # and returns the raw token (to be included in the email link).
  # The raw token is never persisted — only the digest is stored.
  def generate_magic_link_token!
    raw_token = SecureRandom.urlsafe_base64(32)
    update!(
      magic_link_token_digest: Digest::SHA256.hexdigest(raw_token),
      magic_link_token_sent_at: Time.current
    )
    raw_token
  end

  # Finds a user by raw token and validates it hasn't expired.
  # Returns the user if valid, nil otherwise.
  # This is a class method that bypasses tenant scoping since
  # authentication happens before we know which tenant is involved.
  def self.find_by_magic_link_token(raw_token)
    return nil if raw_token.blank?

    digest = Digest::SHA256.hexdigest(raw_token)
    user = ActsAsTenant.without_tenant { find_by(magic_link_token_digest: digest) }
    return nil unless user
    return nil unless user.magic_link_token_valid?

    user
  end

  # Checks if the stored magic link token is still within the expiry window.
  def magic_link_token_valid?
    magic_link_token_digest.present? &&
      magic_link_token_sent_at.present? &&
      magic_link_token_sent_at > MAGIC_LINK_TOKEN_EXPIRY.ago
  end

  # Consumes the token (single-use): clears the digest so it can't be reused.
  def consume_magic_link_token!
    update!(
      magic_link_token_digest: nil,
      magic_link_token_sent_at: nil
    )
  end

  # --- Role checks ---

  def admin?
    role == "admin"
  end

  def hiring_manager?
    role == "hiring_manager"
  end

  def interviewer?
    role == "interviewer"
  end

  # Role hierarchy: admin > hiring_manager > interviewer
  ROLE_HIERARCHY = {"admin" => 3, "hiring_manager" => 2, "interviewer" => 1}.freeze

  def at_least_hiring_manager?
    admin? || hiring_manager?
  end

  def at_least_interviewer?
    ROLE_HIERARCHY.key?(role)
  end

  # Generic role hierarchy check: does this user have at least the given role?
  # e.g. user.role_at_least?(:hiring_manager) returns true for admin and hiring_manager
  def role_at_least?(minimum_role)
    min_level = ROLE_HIERARCHY[minimum_role.to_s]
    return false unless min_level

    (ROLE_HIERARCHY[role] || 0) >= min_level
  end

  def active?
    discarded_at.nil?
  end

  def discarded?
    discarded_at.present?
  end

  def discard!
    update!(discarded_at: Time.current)
  end

  def undiscard!
    update!(discarded_at: nil)
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  # Returns true if this user is the only active admin in the tenant.
  # Used to prevent removal of the last admin.
  def sole_admin?
    return false unless admin?

    self.class.where(role: "admin").active.where.not(id: id).none?
  end

  private

  # Prevents demoting the last admin in a tenant.
  # This is a model-level guard complementing the controller-level check,
  # ensuring data integrity even when updates bypass controllers.
  def must_retain_at_least_one_admin
    return unless role_was == "admin" && role != "admin"

    other_active_admins = self.class.where(role: "admin").where.not(id: id)
    if other_active_admins.none?
      errors.add(:role, "cannot be changed: at least one admin must exist in the organization")
    end
  end

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
