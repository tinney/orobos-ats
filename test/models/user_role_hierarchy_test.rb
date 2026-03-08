# frozen_string_literal: true

require "test_helper"

# Model-level tests verifying the additive role hierarchy:
#   Admin ⊃ Hiring Manager ⊃ Interviewer
#
# Ensures role_at_least? is transitive and that each higher role
# can do everything the lower role can (and more).
class UserRoleHierarchyTest < ActiveSupport::TestCase
  setup do
    @company = Company.create!(name: "Hierarchy Corp", subdomain: "rolehier")
    ActsAsTenant.current_tenant = @company

    @admin = User.create!(
      company: @company, email: "admin@rolehier.com",
      first_name: "Ada", last_name: "Admin", role: "admin"
    )
    @hm = User.create!(
      company: @company, email: "hm@rolehier.com",
      first_name: "Hannah", last_name: "Manager", role: "hiring_manager"
    )
    @interviewer = User.create!(
      company: @company, email: "iv@rolehier.com",
      first_name: "Ivan", last_name: "Viewer", role: "interviewer"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  # =====================================================
  # Additive hierarchy: role_at_least? transitivity
  # =====================================================

  test "admin satisfies every role level" do
    assert @admin.role_at_least?(:admin)
    assert @admin.role_at_least?(:hiring_manager)
    assert @admin.role_at_least?(:interviewer)
  end

  test "hiring_manager satisfies hiring_manager and interviewer but not admin" do
    assert_not @hm.role_at_least?(:admin)
    assert @hm.role_at_least?(:hiring_manager)
    assert @hm.role_at_least?(:interviewer)
  end

  test "interviewer satisfies only interviewer" do
    assert_not @interviewer.role_at_least?(:admin)
    assert_not @interviewer.role_at_least?(:hiring_manager)
    assert @interviewer.role_at_least?(:interviewer)
  end

  # =====================================================
  # Superset verification: anything HM can do, admin can too
  # =====================================================

  test "every capability HM has, admin also has" do
    %i[interviewer hiring_manager].each do |role|
      assert @admin.role_at_least?(role),
        "Admin should satisfy #{role} since Admin ⊃ HM"
      assert @hm.role_at_least?(role),
        "HM should satisfy #{role}"
    end
  end

  test "every capability interviewer has, HM and admin also have" do
    assert @admin.role_at_least?(:interviewer),
      "Admin should satisfy interviewer level"
    assert @hm.role_at_least?(:interviewer),
      "HM should satisfy interviewer level"
    assert @interviewer.role_at_least?(:interviewer),
      "Interviewer should satisfy interviewer level"
  end

  # =====================================================
  # Strict ordering: lower roles cannot reach higher
  # =====================================================

  test "interviewer cannot reach hiring_manager or admin level" do
    assert_not @interviewer.role_at_least?(:hiring_manager),
      "Interviewer should NOT satisfy hiring_manager"
    assert_not @interviewer.role_at_least?(:admin),
      "Interviewer should NOT satisfy admin"
  end

  test "hiring_manager cannot reach admin level" do
    assert_not @hm.role_at_least?(:admin),
      "HM should NOT satisfy admin"
  end

  # =====================================================
  # Convenience methods reflect hierarchy correctly
  # =====================================================

  test "at_least_hiring_manager? is true for admin and hm only" do
    assert @admin.at_least_hiring_manager?
    assert @hm.at_least_hiring_manager?
    assert_not @interviewer.at_least_hiring_manager?
  end

  test "at_least_interviewer? is true for all valid roles" do
    assert @admin.at_least_interviewer?
    assert @hm.at_least_interviewer?
    assert @interviewer.at_least_interviewer?
  end

  # =====================================================
  # ROLE_HIERARCHY numeric levels are strictly ordered
  # =====================================================

  test "role hierarchy levels are strictly increasing" do
    levels = User::ROLE_HIERARCHY
    assert levels["admin"] > levels["hiring_manager"],
      "Admin level must be > HM level"
    assert levels["hiring_manager"] > levels["interviewer"],
      "HM level must be > Interviewer level"
  end

  test "all defined roles have hierarchy entries" do
    User::ROLES.each do |role|
      assert User::ROLE_HIERARCHY.key?(role),
        "Role '#{role}' must have a ROLE_HIERARCHY entry"
    end
  end

  # =====================================================
  # Edge cases
  # =====================================================

  test "role_at_least? with string argument works same as symbol" do
    assert @admin.role_at_least?("admin")
    assert @admin.role_at_least?("hiring_manager")
    assert_not @interviewer.role_at_least?("admin")
  end

  test "role_at_least? with unknown role returns false" do
    assert_not @admin.role_at_least?(:superadmin)
    assert_not @admin.role_at_least?(:nonexistent)
  end

  # =====================================================
  # Exhaustive matrix: for every pair (user_role, required_role)
  # verify the expected result
  # =====================================================

  EXPECTED_MATRIX = {
    # [user_role, required_role] => expected result
    ["admin", "admin"] => true,
    ["admin", "hiring_manager"] => true,
    ["admin", "interviewer"] => true,
    ["hiring_manager", "admin"] => false,
    ["hiring_manager", "hiring_manager"] => true,
    ["hiring_manager", "interviewer"] => true,
    ["interviewer", "admin"] => false,
    ["interviewer", "hiring_manager"] => false,
    ["interviewer", "interviewer"] => true
  }.freeze

  EXPECTED_MATRIX.each do |(user_role, required_role), expected|
    test "role_at_least? matrix: #{user_role} >= #{required_role} is #{expected}" do
      user = User.new(role: user_role)
      assert_equal expected, user.role_at_least?(required_role),
        "Expected #{user_role}.role_at_least?(#{required_role}) to be #{expected}"
    end
  end
end
