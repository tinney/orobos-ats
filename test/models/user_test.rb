require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @company = Company.create!(name: "Test Corp", subdomain: "testcorp")
    ActsAsTenant.current_tenant = @company
    @user = User.create!(
      company: @company,
      email: "user@example.com",
      first_name: "Jane",
      last_name: "Doe",
      role: "admin"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  # --- Validations ---

  test "valid user with all required attributes" do
    assert @user.valid?
  end

  test "requires email" do
    @user.email = nil
    assert_not @user.valid?
    assert_includes @user.errors[:email], "can't be blank"
  end

  test "requires valid email format" do
    @user.email = "not-an-email"
    assert_not @user.valid?
    assert @user.errors[:email].any?
  end

  test "email must be globally unique (case insensitive)" do
    duplicate = User.new(
      company: @company,
      email: "USER@example.com",
      first_name: "John",
      last_name: "Smith",
      role: "interviewer"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "normalizes email to lowercase and strips whitespace" do
    user = User.create!(
      company: @company,
      email: "  FOO@Bar.COM  ",
      first_name: "Foo",
      last_name: "Bar",
      role: "interviewer"
    )
    assert_equal "foo@bar.com", user.email
  end

  test "requires first_name" do
    @user.first_name = nil
    assert_not @user.valid?
    assert_includes @user.errors[:first_name], "can't be blank"
  end

  test "requires last_name" do
    @user.last_name = nil
    assert_not @user.valid?
    assert_includes @user.errors[:last_name], "can't be blank"
  end

  test "requires role" do
    @user.role = nil
    assert_not @user.valid?
    assert_includes @user.errors[:role], "can't be blank"
  end

  test "role must be one of admin, hiring_manager, interviewer" do
    %w[admin hiring_manager interviewer].each do |valid_role|
      @user.role = valid_role
      assert @user.valid?, "Expected #{valid_role} to be valid"
    end

    @user.role = "superadmin"
    assert_not @user.valid?
    assert_includes @user.errors[:role], "is not included in the list"
  end

  # --- Role enum methods ---

  test "admin? returns true for admin role" do
    @user.role = "admin"
    assert @user.admin?
    assert_not @user.hiring_manager?
    assert_not @user.interviewer?
  end

  test "hiring_manager? returns true for hiring_manager role" do
    @user.role = "hiring_manager"
    assert @user.hiring_manager?
    assert_not @user.admin?
    assert_not @user.interviewer?
  end

  test "interviewer? returns true for interviewer role" do
    @user.role = "interviewer"
    assert @user.interviewer?
    assert_not @user.admin?
    assert_not @user.hiring_manager?
  end

  test "at_least_hiring_manager? returns true for admin and hiring_manager" do
    @user.role = "admin"
    assert @user.at_least_hiring_manager?

    @user.role = "hiring_manager"
    assert @user.at_least_hiring_manager?

    @user.role = "interviewer"
    assert_not @user.at_least_hiring_manager?
  end

  test "at_least_interviewer? returns true for all valid roles" do
    %w[admin hiring_manager interviewer].each do |valid_role|
      @user.role = valid_role
      assert @user.at_least_interviewer?, "Expected #{valid_role} to be at_least_interviewer?"
    end
  end

  test "ROLE_HIERARCHY defines correct ordering" do
    assert_equal 3, User::ROLE_HIERARCHY["admin"]
    assert_equal 2, User::ROLE_HIERARCHY["hiring_manager"]
    assert_equal 1, User::ROLE_HIERARCHY["interviewer"]
  end

  # --- role_at_least? ---

  test "role_at_least? admin can satisfy all role requirements" do
    @user.role = "admin"
    assert @user.role_at_least?(:admin)
    assert @user.role_at_least?(:hiring_manager)
    assert @user.role_at_least?(:interviewer)
  end

  test "role_at_least? hiring_manager satisfies hm and interviewer but not admin" do
    @user.role = "hiring_manager"
    assert_not @user.role_at_least?(:admin)
    assert @user.role_at_least?(:hiring_manager)
    assert @user.role_at_least?(:interviewer)
  end

  test "role_at_least? interviewer only satisfies interviewer requirement" do
    @user.role = "interviewer"
    assert_not @user.role_at_least?(:admin)
    assert_not @user.role_at_least?(:hiring_manager)
    assert @user.role_at_least?(:interviewer)
  end

  test "role_at_least? accepts string argument" do
    @user.role = "admin"
    assert @user.role_at_least?("admin")
    assert @user.role_at_least?("hiring_manager")
  end

  test "role_at_least? returns false for unknown role" do
    @user.role = "admin"
    assert_not @user.role_at_least?(:superadmin)
  end

  # --- Soft-delete ---

  test "active? returns true when discarded_at is nil" do
    assert @user.active?
    assert_not @user.discarded?
  end

  test "discarded? returns true when discarded_at is set" do
    @user.discard!
    assert @user.discarded?
    assert_not @user.active?
    assert @user.discarded_at.present?
  end

  test "discard! sets discarded_at timestamp" do
    assert_nil @user.discarded_at
    @user.discard!
    assert @user.discarded_at.present?
  end

  test "undiscard! clears discarded_at timestamp" do
    @user.discard!
    assert @user.discarded?
    @user.undiscard!
    assert @user.active?
    assert_nil @user.discarded_at
  end

  # --- Scopes ---

  test "active scope returns only users without discarded_at" do
    active_user = @user
    discarded_user = User.create!(
      company: @company,
      email: "discarded@example.com",
      first_name: "Old",
      last_name: "User",
      role: "interviewer",
      discarded_at: Time.current
    )

    active_users = User.active
    assert_includes active_users, active_user
    assert_not_includes active_users, discarded_user
  end

  test "discarded scope returns only users with discarded_at" do
    active_user = @user
    discarded_user = User.create!(
      company: @company,
      email: "discarded@example.com",
      first_name: "Old",
      last_name: "User",
      role: "interviewer",
      discarded_at: Time.current
    )

    discarded_users = User.discarded
    assert_includes discarded_users, discarded_user
    assert_not_includes discarded_users, active_user
  end

  # --- full_name ---

  test "full_name concatenates first_name and last_name" do
    assert_equal "Jane Doe", @user.full_name
  end

  # --- ROLES constant ---

  test "ROLES constant contains all valid roles" do
    assert_equal %w[admin hiring_manager interviewer], User::ROLES
  end

  # --- acts_as_tenant ---

  test "user belongs to company" do
    assert_equal @company, @user.company
  end

  test "users are scoped to current tenant" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp")
    ActsAsTenant.with_tenant(other_company) do
      other_user = User.create!(
        company: other_company,
        email: "other@example.com",
        first_name: "Other",
        last_name: "User",
        role: "admin"
      )
      assert_includes User.all, other_user
    end

    # Original tenant should not see the other user
    assert_equal 1, User.count
  end

  # --- sole_admin? ---

  test "sole_admin? returns true when user is the only active admin" do
    assert @user.sole_admin?
  end

  test "sole_admin? returns false when another active admin exists" do
    User.create!(
      company: @company,
      email: "admin2@example.com",
      first_name: "Other",
      last_name: "Admin",
      role: "admin"
    )
    assert_not @user.sole_admin?
  end

  test "sole_admin? returns true when other admins are deactivated" do
    other_admin = User.create!(
      company: @company,
      email: "admin2@example.com",
      first_name: "Other",
      last_name: "Admin",
      role: "admin"
    )
    other_admin.discard!
    assert @user.sole_admin?
  end

  test "sole_admin? returns false for non-admin users" do
    @user.role = "hiring_manager"
    @user.save!
    assert_not @user.sole_admin?
  end

  # --- Default role ---

  test "default role is interviewer at database level" do
    user = User.create!(
      company: @company,
      email: "default@example.com",
      first_name: "Default",
      last_name: "Role"
    )
    assert_equal "interviewer", user.role
  end
end
