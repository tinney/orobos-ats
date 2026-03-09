class Tenant < ApplicationRecord
  RESERVED_SUBDOMAINS = %w[
    www admin api mail app staging production
    ftp smtp imap pop pop3 ns ns1 ns2
    blog help support status docs
    assets cdn static media
    test dev local localhost
  ].freeze

  validates :company_name, presence: true
  validates :admin_email, presence: true,
    format: {with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address"},
    uniqueness: {case_sensitive: false}
  validates :subdomain, presence: true,
    uniqueness: {case_sensitive: false},
    length: {minimum: 2, maximum: 63},
    format: {
      with: /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?\z/,
      message: "must be lowercase alphanumeric with hyphens (cannot start or end with a hyphen)"
    }
  validates :slug, presence: true,
    uniqueness: {case_sensitive: false},
    format: {
      with: /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?\z/,
      message: "must be lowercase alphanumeric with hyphens"
    }
  validate :subdomain_not_reserved

  before_validation :normalize_subdomain
  before_validation :set_slug_from_subdomain, if: -> { slug.blank? }

  private

  def normalize_subdomain
    self.subdomain = subdomain&.strip&.downcase
  end

  def set_slug_from_subdomain
    self.slug = subdomain
  end

  def subdomain_not_reserved
    if RESERVED_SUBDOMAINS.include?(subdomain)
      errors.add(:subdomain, "is reserved and cannot be used")
    end
  end
end
