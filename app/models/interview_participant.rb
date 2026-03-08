# frozen_string_literal: true

class InterviewParticipant < ApplicationRecord
  belongs_to :interview
  belongs_to :user

  validates :user_id, uniqueness: {
    scope: :interview_id,
    message: "is already assigned to this interview"
  }
end
