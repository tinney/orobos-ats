require "test_helper"

class SignupsControllerTest < ActionDispatch::IntegrationTest
  test "GET signup renders the form" do
    get signup_path
    assert_response :success
    assert_select "form"
    assert_select "input[name='signup[company_name]']"
    assert_select "input[name='signup[subdomain]']"
    assert_select "input[name='signup[admin_email]']"
    assert_select "input[name='signup[admin_first_name]']"
    assert_select "input[name='signup[admin_last_name]']"
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
end
