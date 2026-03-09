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

  test "magic_link email contains auth callback URL with subdomain and token" do
    token = "test-token-abc123"
    email = AuthMailer.magic_link(@user, token, "testcorp")

    # URL should route to the tenant subdomain callback
    assert_match %r{testcorp\..*\/auth\/callback\?token=test-token-abc123}, email.body.encoded
  end

  test "magic_link email has both HTML and text parts" do
    token = "test-token-abc123"
    email = AuthMailer.magic_link(@user, token, "testcorp")

    assert email.multipart?, "Email should be multipart (HTML + text)"
    assert email.html_part.present?, "Email should have an HTML part"
    assert email.text_part.present?, "Email should have a text part"
  end

  test "magic_link text part contains the full URL" do
    token = "test-token-abc123"
    email = AuthMailer.magic_link(@user, token, "testcorp")

    text_body = email.text_part.body.decoded
    assert_match %r{http.*testcorp\..*\/auth\/callback\?token=test-token-abc123}, text_body
  end

  test "magic_link HTML part contains a sign-in button link" do
    token = "test-token-abc123"
    email = AuthMailer.magic_link(@user, token, "testcorp")

    html_body = email.html_part.body.decoded
    assert_match "Sign in now", html_body
    assert_match %r{href=.*auth/callback\?token=test-token-abc123}, html_body
  end

  test "magic_link email includes security disclaimer" do
    token = "test-token-abc123"
    email = AuthMailer.magic_link(@user, token, "testcorp")

    assert_match(/didn.*t request this link/i, email.body.encoded)
  end
end
