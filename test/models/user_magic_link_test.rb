require "test_helper"

class UserMagicLinkTest < ActiveSupport::TestCase
  setup do
    @company = Company.create!(name: "Test Corp", subdomain: "testcorp")
    ActsAsTenant.current_tenant = @company
    @user = User.create!(
      company: @company,
      email: "admin@testcorp.com",
      first_name: "Jane",
      last_name: "Doe",
      role: "admin"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "generate_magic_link_token! returns a raw token and stores digest" do
    raw_token = @user.generate_magic_link_token!

    assert raw_token.present?
    assert @user.magic_link_token_digest.present?
    assert @user.magic_link_token_sent_at.present?

    # The stored digest should be the SHA256 of the raw token
    expected_digest = Digest::SHA256.hexdigest(raw_token)
    assert_equal expected_digest, @user.magic_link_token_digest
  end

  test "generate_magic_link_token! produces unique tokens each time" do
    token1 = @user.generate_magic_link_token!
    token2 = @user.generate_magic_link_token!

    assert_not_equal token1, token2
  end

  test "find_by_magic_link_token returns user for valid token" do
    raw_token = @user.generate_magic_link_token!
    found_user = User.find_by_magic_link_token(raw_token)

    assert_equal @user, found_user
  end

  test "find_by_magic_link_token returns nil for blank token" do
    assert_nil User.find_by_magic_link_token(nil)
    assert_nil User.find_by_magic_link_token("")
  end

  test "find_by_magic_link_token returns nil for invalid token" do
    @user.generate_magic_link_token!
    assert_nil User.find_by_magic_link_token("bogus-token-value")
  end

  test "find_by_magic_link_token returns nil for expired token" do
    raw_token = @user.generate_magic_link_token!

    # Simulate token being sent 16 minutes ago (past 15-min expiry)
    @user.update_column(:magic_link_token_sent_at, 16.minutes.ago)

    assert_nil User.find_by_magic_link_token(raw_token)
  end

  test "magic_link_token_valid? returns true within expiry window" do
    @user.generate_magic_link_token!
    assert @user.magic_link_token_valid?
  end

  test "magic_link_token_valid? returns false after expiry" do
    @user.generate_magic_link_token!
    @user.update_column(:magic_link_token_sent_at, 16.minutes.ago)

    assert_not @user.magic_link_token_valid?
  end

  test "magic_link_token_valid? returns false when no token exists" do
    assert_not @user.magic_link_token_valid?
  end

  test "consume_magic_link_token! clears the token digest and timestamp" do
    raw_token = @user.generate_magic_link_token!
    @user.consume_magic_link_token!

    assert_nil @user.magic_link_token_digest
    assert_nil @user.magic_link_token_sent_at

    # Token should no longer be findable
    assert_nil User.find_by_magic_link_token(raw_token)
  end

  test "token is single-use — consumed token cannot be reused" do
    raw_token = @user.generate_magic_link_token!

    # First lookup succeeds
    found = User.find_by_magic_link_token(raw_token)
    assert_equal @user, found

    # Consume it
    @user.consume_magic_link_token!

    # Second lookup fails
    assert_nil User.find_by_magic_link_token(raw_token)
  end

  test "find_by_magic_link_token works without tenant scoping" do
    # Clear tenant context to simulate pre-auth scenario
    ActsAsTenant.current_tenant = nil

    raw_token = nil
    ActsAsTenant.with_tenant(@company) do
      raw_token = @user.generate_magic_link_token!
    end

    # Should find user even without tenant set
    found_user = User.find_by_magic_link_token(raw_token)
    assert_equal @user, found_user
  end
end
