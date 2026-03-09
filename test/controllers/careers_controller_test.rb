require "test_helper"

class CareersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @company = Company.create!(name: "Acme Corp", subdomain: "acme", primary_color: "#E11D48")
    ActsAsTenant.with_tenant(@company) do
      @published_role = Role.create!(
        company: @company,
        title: "Software Engineer",
        status: "draft",
        location: "San Francisco, CA",
        remote: false
      )
      @published_role.update_column(:status, "published")

      @draft_role = Role.create!(
        company: @company,
        title: "Draft Role",
        status: "draft"
      )

      @closed_role = Role.create!(
        company: @company,
        title: "Closed Role",
        status: "draft"
      )
      @closed_role.update_column(:status, "closed")

      @internal_role = Role.create!(
        company: @company,
        title: "Internal Only Role",
        status: "draft"
      )
      @internal_role.update_column(:status, "internal_only")
    end

    @other_company = Company.create!(name: "Other Inc", subdomain: "other")
    ActsAsTenant.with_tenant(@other_company) do
      @other_role = Role.create!(
        company: @other_company,
        title: "Other Role",
        status: "draft"
      )
      @other_role.update_column(:status, "published")
    end

    host! "acme.example.com"
  end

  # ==========================================
  # Subdomain routing
  # ==========================================

  test "careers index is accessible on tenant subdomain" do
    get careers_path
    assert_response :success
  end

  test "unknown subdomain returns not found" do
    host! "nonexistent.example.com"
    get careers_path
    assert_response :not_found
  end

  # ==========================================
  # Index — only published roles
  # ==========================================

  test "index shows published roles" do
    get careers_path
    assert_response :success
    assert_match "Software Engineer", response.body
  end

  test "index does not show draft roles" do
    get careers_path
    assert_response :success
    refute_match "Draft Role", response.body
  end

  test "index does not show closed roles" do
    get careers_path
    assert_response :success
    refute_match "Closed Role", response.body
  end

  test "index does not show internal_only roles" do
    get careers_path
    assert_response :success
    refute_match "Internal Only Role", response.body
  end

  test "index does not show roles from other tenants" do
    get careers_path
    assert_response :success
    refute_match "Other Role", response.body
  end

  test "index shows empty state when no published roles" do
    ActsAsTenant.with_tenant(@company) do
      @published_role.update_column(:status, "closed")
    end
    get careers_path
    assert_response :success
    assert_match "No open positions", response.body
  end

  # ==========================================
  # Show — single published role
  # ==========================================

  test "show displays a published role" do
    get career_path(@published_role)
    assert_response :success
    assert_match "Software Engineer", response.body
  end

  test "show returns not found for draft role" do
    get career_path(@draft_role)
    assert_response :not_found
  end

  test "show returns not found for closed role" do
    get career_path(@closed_role)
    assert_response :not_found
  end

  test "show returns not found for internal_only role" do
    get career_path(@internal_role)
    assert_response :not_found
  end

  test "show returns not found for non-existent role ID" do
    get career_path(id: "00000000-0000-0000-0000-000000000000")
    assert_response :not_found
  end

  test "show returns not found for other tenant role" do
    get career_path(@other_role)
    assert_response :not_found
  end

  test "show displays role title in heading" do
    get career_path(@published_role)
    assert_response :success
    assert_select "h1", text: "Software Engineer"
  end

  test "show displays role location" do
    get career_path(@published_role)
    assert_response :success
    assert_includes response.body, "San Francisco, CA"
  end

  test "show displays remote badge when role is remote" do
    ActsAsTenant.with_tenant(@company) do
      @published_role.update_column(:remote, true)
    end
    get career_path(@published_role)
    assert_response :success
    assert_includes response.body, "Remote"
  end

  test "show does not display remote badge when role is not remote" do
    get career_path(@published_role)
    assert_response :success
    refute_select "span", text: "Remote"
  end

  test "show displays salary range when present" do
    ActsAsTenant.with_tenant(@company) do
      @published_role.update_columns(salary_min: 100_000, salary_max: 150_000, salary_currency: "USD")
    end
    get career_path(@published_role)
    assert_response :success
    assert_includes response.body, "USD"
    assert_includes response.body, "100,000"
    assert_includes response.body, "150,000"
  end

  test "show displays rich text description" do
    ActsAsTenant.with_tenant(@company) do
      @published_role.update!(description: "<p>We are looking for a talented engineer.</p>")
    end
    get career_path(@published_role)
    assert_response :success
    assert_includes response.body, "We are looking for a talented engineer"
  end

  test "show displays empty state when no description" do
    get career_path(@published_role)
    assert_response :success
    assert_includes response.body, "No description available"
  end

  test "show displays back link to careers index" do
    get career_path(@published_role)
    assert_response :success
    assert_select "a[href='#{careers_path}']", text: /Back to all positions/
  end

  test "show displays apply button with tenant primary color" do
    get career_path(@published_role)
    assert_response :success
    assert_includes response.body, "Apply for this position"
    assert_includes response.body, "background-color: #E11D48"
  end

  test "show uses careers layout with company branding" do
    get career_path(@published_role)
    assert_response :success
    assert_select "h1", text: "Acme Corp"
    assert_select "title", text: /Acme Corp/
  end

  test "show is accessible without authentication" do
    get career_path(@published_role)
    assert_response :success
  end

  test "show page is mobile-responsive" do
    get career_path(@published_role)
    assert_response :success
    assert_select "meta[name='viewport'][content='width=device-width, initial-scale=1']"
  end

  # ==========================================
  # No authentication required
  # ==========================================

  test "careers pages do not require authentication" do
    get careers_path
    assert_response :success

    get career_path(@published_role)
    assert_response :success
  end

  # ==========================================
  # Tenant branding
  # ==========================================

  test "index shows company name in header branding" do
    get careers_path
    assert_response :success
    assert_select "h1", text: "Acme Corp"
  end

  test "index shows primary color as CSS variable" do
    get careers_path
    assert_response :success
    assert_includes response.body, "--brand-color: #E11D48"
  end

  test "index shows fallback initial when no logo" do
    get careers_path
    assert_response :success
    # Fallback shows first letter of company name
    assert_select "div", text: "A"
  end

  test "index uses careers layout with footer branding" do
    get careers_path
    assert_response :success
    assert_select "footer"
    assert_includes response.body, "Powered by"
    assert_includes response.body, "Ouroboros"
  end

  test "index page title includes company name" do
    get careers_path
    assert_response :success
    assert_select "title", text: /Acme Corp/
  end

  test "index is mobile-responsive with viewport meta tag" do
    get careers_path
    assert_response :success
    assert_select "meta[name='viewport'][content='width=device-width, initial-scale=1']"
  end

  test "index shows role location and remote badge" do
    get careers_path
    assert_response :success
    assert_includes response.body, "San Francisco, CA"
  end

  test "index header links to careers index" do
    get careers_path
    assert_response :success
    assert_select "header a[href='#{careers_path}']"
  end

  test "index shows company description when present" do
    @company.update!(description: "We build great software")
    get careers_path
    assert_response :success
    assert_includes response.body, "We build great software"
  end

  test "index connects careers Stimulus controller" do
    get careers_path
    assert_response :success
    assert_select "[data-controller='careers']"
  end

  test "index uses default primary color when none set" do
    @company.update_column(:primary_color, nil)
    get careers_path
    assert_response :success
    # Should use default fallback color in inline styles
    assert_includes response.body, "#4F46E5"
  end

  test "role titles are styled with tenant primary color" do
    get careers_path
    assert_response :success
    assert_includes response.body, "color: #E11D48"
  end
end
