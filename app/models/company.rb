class Company < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_one_attached :logo

  validates :name, presence: true
  validates :subdomain, presence: true,
                         uniqueness: { case_sensitive: false },
                         length: { minimum: 3, maximum: 63 },
                         format: {
                           with: /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/,
                           message: "must start and end with a letter or number, and contain only lowercase letters, numbers, and hyphens"
                         }

  RESERVED_SUBDOMAINS = %w[
    www app api admin mail ftp smtp pop imap ns ns1 ns2
    staging demo test blog help support status docs
    assets cdn static media images files
    signup login auth sso callback
    careers jobs apply hire
  ].freeze

  validate :subdomain_not_reserved

  before_validation :normalize_subdomain

  private

  def normalize_subdomain
    self.subdomain = subdomain.to_s.strip.downcase
  end

  def subdomain_not_reserved
    if RESERVED_SUBDOMAINS.include?(subdomain)
      errors.add(:subdomain, "is reserved and cannot be used")
    end
  end
end
