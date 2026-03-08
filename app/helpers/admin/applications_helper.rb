module Admin::ApplicationsHelper
  def can_view_scorecard?(scorecard, interview)
    return true if current_user.admin?
    return true if current_user.at_least_hiring_manager?
    phase = interview.interview_phase
    return true if phase.phase_owner_id == current_user.id
    scorecard.user_id == current_user.id
  end
end
