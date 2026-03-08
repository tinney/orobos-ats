require "test_helper"

class AuthMailerTest < ActionMailer::TestCase
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

  test "magic_link email is sent to user with correct subject" do
    token = "test-token-abc123"
    email = AuthMailer.magic_link(@user, token, "testcorp")

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal ["admin@testcorp.com"], email.to
    assert_equal "Your sign-in link", email.subject
  end

  test "magic_link email contains the sign-in link with token" do
    token = "test-token-abc123"
    email = AuthMailer.magic_link(@user, token, "testcorp")

    assert_match token, email.body.encoded
    assert_match "testcorp", email.body.encoded
  end

  test "magic_link email contains expiry notice" do
    token = "test-token-abc123"
    email = AuthMailer.magic_link(@user, token, "testcorp")

    assert_match "15 minutes", email.body.encoded
  end

  test "magic_link email is sent from platform noreply address" do
    token = "test-token-abc123"
    email = AuthMailer.magic_link(@user, token, "testcorp")

    assert email.from.first.include?("noreply")
  end

  test "magic_link email includes user first name" do
    token = "test-token-abc123"
    email = AuthMailer.magic_link(@user, token, "testcorp")

    assert_match "Jane", email.body.encoded
  end
end
