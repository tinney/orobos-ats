# frozen_string_literal: true

class PanelInterview < ApplicationRecord
  belongs_to :interview
  belongs_to :user

  attr_accessor :skip_last_member_check

  validates :user_id, uniqueness: {
    scope: :interview_id,
    message: "is already a panel member for this interview"
  }

  # Prevent removing the last panel member from an interview.
  # Every interview panel must have at least one interviewer.
  before_destroy :ensure_not_last_panel_member, unless: :skip_last_member_check

  private

  def ensure_not_last_panel_member
    if interview.panel_interviews.count <= 1
      errors.add(:base, "Cannot remove the last panel member from an interview")
      throw(:abort)
    end
  end
end
