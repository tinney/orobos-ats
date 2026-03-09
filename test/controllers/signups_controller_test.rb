require "test_helper"

class SignupsControllerTest < ActionDispatch::IntegrationTest
  test "GET signup renders the form with Stimulus validation controller" do
    get signup_path
    assert_response :success
    assert_select "form[data-controller='signup-form']"
    assert_select "form[data-action='submit->signup-form#validate']"
    assert_select "input[name='signup[company_name]'][data-signup-form-target='companyName']"
    assert_select "input[name='signup[subdomain]'][data-signup-form-target='subdomain']"
    assert_select "input[name='signup[admin_email]'][data-signup-form-target='adminEmail']"
    assert_select "input[name='signup[admin_first_name]'][data-signup-form-target='adminFirstName']"
    assert_select "input[name='signup[admin_last_name]'][data-signup-form-target='adminLastName']"
    assert_select "input[type='submit'][data-signup-form-target='submitButton']"
  end

  test "POST signup with valid data creates tenant and redirects" do
    post signup_path, params: {
      signup: {
        company_name: "Test Corp",
        subdomain: "testcorp",
        admin_email: "admin@testcorp.com",
        admin_first_name: "Test",
        admin_last_name: "Admin"
      }
    }

    assert_redirected_to signup_success_path(tenant_subdomain: "testcorp")

    company = Company.find_by!(subdomain: "testcorp")
    assert_equal "Test Corp", company.name

    ActsAsTenant.with_tenant(company) do
      user = company.users.first
      assert_equal "admin@testcorp.com", user.email
      assert_equal "admin", user.role
    end
  end

  test "POST signup with invalid data renders form with errors" do
    assert_no_difference "Company.count" do
      post signup_path, params: {
        signup: {
          company_name: "",
          subdomain: "ab",
          admin_email: "bad",
          admin_first_name: "",
          admin_last_name: ""
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "POST signup with duplicate subdomain shows error" do
    TenantSignupService.new(
      company_name: "Existing",
      subdomain: "taken",
      admin_email: "existing@example.com",
      admin_first_name: "Existing",
      admin_last_name: "User"
    ).call

    assert_no_difference "Company.count" do
      post signup_path, params: {
        signup: {
          company_name: "New Corp",
          subdomain: "taken",
          admin_email: "admin@new.com",
          admin_first_name: "New",
          admin_last_name: "Admin"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "GET signup/success shows success page" do
    get signup_success_path(tenant_subdomain: "testcorp")
    assert_response :success
    assert_select "strong", text: /testcorp/
  end

  test "root path renders marketing landing page" do
    get root_path
    assert_response :success
    # Root now serves marketing page; signup is at /signup
  end

  test "check_subdomain returns available for valid unused subdomain" do
    get check_subdomain_path, params: { subdomain: "newcompany" }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert json["available"]
    assert_match(/available/, json["message"])
  end

  test "check_subdomain returns unavailable for taken subdomain" do
    TenantSignupService.new(
      company_name: "Existing",
      subdomain: "existing",
      admin_email: "admin@existing.com",
      admin_first_name: "Admin",
      admin_last_name: "User"
    ).call

    get check_subdomain_path, params: { subdomain: "existing" }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_not json["available"]
    assert_match(/taken/, json["message"])
  end

  test "check_subdomain returns unavailable for reserved subdomain" do
    get check_subdomain_path, params: { subdomain: "admin" }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_not json["available"]
    assert_match(/reserved/, json["message"])
  end

  test "check_subdomain returns unavailable for too-short subdomain" do
    get check_subdomain_path, params: { subdomain: "ab" }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_not json["available"]
  end

  test "check_subdomain returns unavailable for invalid format" do
    get check_subdomain_path, params: { subdomain: "-bad-" }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_not json["available"]
  end

  test "signup form uses novalidate to rely on Stimulus validation" do
    get signup_path
    assert_response :success
    assert_select "form[novalidate]"
  end
end
