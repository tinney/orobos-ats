# frozen_string_literal: true

require "test_helper"

module Admin
  class SettingsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @company = Company.create!(name: "Acme Corp", subdomain: "acme", primary_color: "#E11D48")
      @admin = User.create!(
        email: "admin@acme.com",
        first_name: "Admin",
        last_name: "User",
        role: "admin",
        company: @company
      )
      @interviewer = User.create!(
        email: "interviewer@acme.com",
        first_name: "Int",
        last_name: "Viewer",
        role: "interviewer",
        company: @company
      )

      ActsAsTenant.current_tenant = @company
      host! "acme.example.com"
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

    # ── Authentication & Authorization ──

    test "unauthenticated user is redirected to login" do
      get edit_admin_settings_url
      assert_redirected_to login_url
    end

    test "non-admin user cannot access settings" do
      sign_in(@interviewer)
      get edit_admin_settings_url
      assert_response :redirect
    end

    test "admin user can access settings" do
      sign_in(@admin)
      get edit_admin_settings_url
      assert_response :success
    end

    # ── Edit Page ──

    test "edit page renders company name field" do
      sign_in(@admin)
      get edit_admin_settings_url
      assert_response :success
      assert_select "input[name='company[name]'][value='Acme Corp']"
    end

    test "edit page renders color picker with current value" do
      sign_in(@admin)
      get edit_admin_settings_url
      assert_select "input[name='company[primary_color]'][type='color'][value='#E11D48']"
      assert_select "input[name='company[primary_color]'][type='text'][value='#E11D48']"
    end

    test "edit page renders color preview elements" do
      sign_in(@admin)
      get edit_admin_settings_url
      assert_select "[data-controller='color-preview']"
      assert_select "[data-color-preview-target='sampleButton']"
      assert_select "[data-color-preview-target='sampleLink']"
    end

    test "edit page renders logo upload field" do
      sign_in(@admin)
      get edit_admin_settings_url
      assert_select "input[name='company[logo]'][type='file']"
    end

    # ── Update ──

    test "admin can update company name" do
      sign_in(@admin)
      patch admin_settings_url, params: { company: { name: "New Name Inc" } }
      assert_redirected_to edit_admin_settings_path
      follow_redirect!
      assert_select ".bg-green-50"
      @company.reload
      assert_equal "New Name Inc", @company.name
    end

    test "admin can update primary color" do
      sign_in(@admin)
      patch admin_settings_url, params: { company: { primary_color: "#10B981" } }
      assert_redirected_to edit_admin_settings_path
      @company.reload
      assert_equal "#10B981", @company.primary_color
    end

    test "invalid color format is rejected" do
      sign_in(@admin)
      patch admin_settings_url, params: { company: { primary_color: "not-a-color" } }
      assert_response :unprocessable_entity
      @company.reload
      assert_equal "#E11D48", @company.primary_color
    end

    test "blank company name is rejected" do
      sign_in(@admin)
      patch admin_settings_url, params: { company: { name: "" } }
      assert_response :unprocessable_entity
      @company.reload
      assert_equal "Acme Corp", @company.name
    end

    test "admin can upload a logo" do
      sign_in(@admin)
      logo = fixture_file_upload("test_logo.png", "image/png")
      patch admin_settings_url, params: { company: { logo: logo } }
      assert_redirected_to edit_admin_settings_path
      @company.reload
      assert @company.logo.attached?
    end

    # ── Logo Removal ──

    test "admin can remove an attached logo" do
      sign_in(@admin)
      @company.logo.attach(
        io: StringIO.new("fake image data"),
        filename: "logo.png",
        content_type: "image/png"
      )
      assert @company.logo.attached?

      delete destroy_logo_admin_settings_url
      assert_redirected_to edit_admin_settings_path
      @company.reload
      assert_not @company.logo.attached?
    end

    test "removing logo when none attached shows alert" do
      sign_in(@admin)
      delete destroy_logo_admin_settings_url
      assert_redirected_to edit_admin_settings_path
      follow_redirect!
      assert_select ".bg-red-50"
    end

    # ── Settings link in nav ──

    test "settings link appears in admin nav for admin users" do
      sign_in(@admin)
      get edit_admin_settings_url
      assert_select "a[href='#{edit_admin_settings_path}']", text: "Settings"
    end

    private

    def sign_in(user)
      raw_token = ActsAsTenant.with_tenant(user.company) { user.generate_magic_link_token! }
      get auth_callback_path(token: raw_token)
    end
  end
end
