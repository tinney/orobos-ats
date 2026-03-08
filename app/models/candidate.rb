# frozen_string_literal: true

class Candidate < ApplicationRecord
  acts_as_tenant :company

  belongs_to :company
  has_many :application_submissions, class_name: "ApplicationSubmission", foreign_key: :candidate_id, dependent: :destroy

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { scope: :company_id, case_sensitive: false }
  validates :phone, length: { maximum: 50 }, allow_blank: true

  before_validation :normalize_email

  def full_name
    "#{first_name} #{last_name}"
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
