require "test_helper"

class RoleStatusTransitionTest < ActiveSupport::TestCase
  setup do
    @company = Company.create!(name: "Transition Corp", subdomain: "transitioncorp")
    ActsAsTenant.current_tenant = @company
    @user = User.create!(
      company: @company,
      email: "admin@transitioncorp.com",
      first_name: "Admin",
      last_name: "User",
      role: "admin"
    )
    @owner = User.create!(
      company: @company,
      email: "hm@transitioncorp.com",
      first_name: "Hiring",
      last_name: "Manager",
      role: "hiring_manager"
    )
    @role = Role.create!(
      company: @company,
      title: "Test Engineer"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  # --- Validations ---

  test "valid transition record" do
    transition = RoleStatusTransition.new(
      role: @role,
      company: @company,
      from_status: "draft",
      to_status: "published"
    )
    assert transition.valid?
  end

  test "requires from_status" do
    transition = RoleStatusTransition.new(
      role: @role,
      company: @company,
      from_status: nil,
      to_status: "published"
    )
    assert_not transition.valid?
    assert transition.errors[:from_status].any?
  end

  test "requires to_status" do
    transition = RoleStatusTransition.new(
      role: @role,
      company: @company,
      from_status: "draft",
      to_status: nil
    )
    assert_not transition.valid?
    assert transition.errors[:to_status].any?
  end

  test "from_status must be a valid status" do
    transition = RoleStatusTransition.new(
      role: @role,
      company: @company,
      from_status: "invalid",
      to_status: "published"
    )
    assert_not transition.valid?
  end

  test "to_status must be a valid status" do
    transition = RoleStatusTransition.new(
      role: @role,
      company: @company,
      from_status: "draft",
      to_status: "invalid"
    )
    assert_not transition.valid?
  end

  test "from and to statuses must differ" do
    transition = RoleStatusTransition.new(
      role: @role,
      company: @company,
      from_status: "draft",
      to_status: "draft"
    )
    assert_not transition.valid?
    assert_includes transition.errors[:to_status], "must differ from the current status"
  end

  test "user is optional" do
    transition = RoleStatusTransition.new(
      role: @role,
      company: @company,
      from_status: "draft",
      to_status: "published",
      user: nil
    )
    assert transition.valid?
  end

  # --- Transition recording via Role ---

  test "transition_to! records transition history" do
    assign_phase_owner(@role)
    assert_difference -> { RoleStatusTransition.count }, 1 do
      @role.transition_to!("published", user: @user)
    end
    transition = @role.status_transitions.last
    assert_equal "draft", transition.from_status
    assert_equal "published", transition.to_status
    assert_equal @user, transition.user
    assert_equal @company, transition.company
  end

  test "transition_to! without user records nil user" do
    assign_phase_owner(@role)
    @role.transition_to!("published")
    transition = @role.status_transitions.last
    assert_nil transition.user
  end

  test "multiple transitions create ordered history" do
    assign_phase_owner(@role)
    @role.transition_to!("published", user: @user)
    @role.transition_to!("internal_only", user: @owner)
    @role.transition_to!("closed", user: @user)

    history = @role.transition_history
    assert_equal 3, history.count

    # reverse_chronological: most recent first
    assert_equal "closed", history.first.to_status
    assert_equal "published", history.last.to_status
  end

  test "last_transition returns most recent" do
    assign_phase_owner(@role)
    @role.transition_to!("published", user: @user)
    @role.transition_to!("closed", user: @owner)

    last = @role.last_transition
    assert_equal "published", last.from_status
    assert_equal "closed", last.to_status
    assert_equal @owner, last.user
  end

  test "publish! records transition with user" do
    assign_phase_owner(@role)
    @role.publish!(user: @user)
    transition = @role.status_transitions.last
    assert_equal "draft", transition.from_status
    assert_equal "published", transition.to_status
    assert_equal @user, transition.user
  end

  test "close! records transition with user" do
    assign_phase_owner(@role)
    @role.publish!
    @role.close!(user: @owner)
    transition = @role.status_transitions.last
    assert_equal "published", transition.from_status
    assert_equal "closed", transition.to_status
    assert_equal @owner, transition.user
  end

  test "make_internal_only! records transition" do
    @role.make_internal_only!(user: @user)
    transition = @role.status_transitions.last
    assert_equal "draft", transition.from_status
    assert_equal "internal_only", transition.to_status
  end

  test "failed transition does not record history" do
    assert_no_difference -> { RoleStatusTransition.count } do
      assert_raises(ActiveRecord::RecordInvalid) { @role.transition_to!("closed") }
    end
  end

  test "transitions are tenant-scoped" do
    assign_phase_owner(@role)
    @role.transition_to!("published", user: @user)

    other_company = Company.create!(name: "Other Corp", subdomain: "othertransition")
    ActsAsTenant.with_tenant(other_company) do
      assert_equal 0, RoleStatusTransition.count
    end
  end

  test "transitions are destroyed when role is destroyed" do
    assign_phase_owner(@role)
    @role.transition_to!("published", user: @user)
    assert_equal 1, RoleStatusTransition.count
    @role.destroy!
    assert_equal 0, RoleStatusTransition.count
  end

  # --- Scopes ---

  test "chronological scope orders oldest first" do
    assign_phase_owner(@role)
    @role.transition_to!("published", user: @user)
    @role.transition_to!("closed", user: @user)

    transitions = @role.status_transitions.chronological
    assert_equal "published", transitions.first.to_status
    assert_equal "closed", transitions.last.to_status
  end

  private

  def assign_phase_owner(role)
    phase = role.interview_phases.active.first
    phase.update!(phase_owner: @owner)
  end
end
