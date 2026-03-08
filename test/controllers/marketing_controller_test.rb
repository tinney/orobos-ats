require "test_helper"

class MarketingControllerTest < ActionDispatch::IntegrationTest
  test "GET root renders marketing landing page" do
    get root_path
    assert_response :success
    assert_select "h1", text: /Hiring/
    assert_select "a[href='#{signup_path}']"
  end

  test "landing page includes feature sections" do
    get root_path
    assert_response :success
    assert_select "h3", text: /Candidate Pipeline/
    assert_select "h3", text: /Structured Interviews/
    assert_select "h3", text: /Blind Scorecards/
    assert_select "h3", text: /Bot Detection/
    assert_select "h3", text: /Role-Based Access/
  end

  test "landing page includes how-it-works section" do
    get root_path
    assert_response :success
    assert_select "h2", text: /Up and running/
  end

  test "landing page includes CTA section" do
    get root_path
    assert_response :success
    assert_select "h2", text: /Ready to improve/
  end

  test "landing page includes footer" do
    get root_path
    assert_response :success
    assert_select "footer"
  end

  test "landing page does not require tenant context" do
    # No subdomain set — should work fine
    get root_path
    assert_response :success
  end
end
