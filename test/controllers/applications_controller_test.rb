# frozen_string_literal: true

require "test_helper"

class ApplicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @company = Company.create!(name: "Acme Corp", subdomain: "acme", primary_color: "#E11D48")
    ActsAsTenant.with_tenant(@company) do
      # Create a user to act as phase owner (required for publishing)
      @admin = User.create!(
        company: @company,
        first_name: "Admin",
        last_name: "User",
        email: "admin@acme.com",
        role: "admin"
      )

      @published_role = Role.create!(
        company: @company,
        title: "Software Engineer",
        status: "draft",
        location: "San Francisco, CA"
      )
      @published_role.interview_phases.first.update!(phase_owner: @admin)
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
  # Application form — published role only
  # ==========================================

  test "show renders application form for published role" do
    get job_application_path(slug: @published_role.slug)
    assert_response :success
    assert_select "h1", /Apply for Software Engineer/
    assert_select "form"
    assert_select "input[name='application[first_name]']"
    assert_select "input[name='application[last_name]']"
    assert_select "input[name='application[email]']"
    assert_select "input[name='application[phone]']"
    assert_select "input[name='application[resume]']"
    assert_select "textarea[name='application[cover_letter]']"
  end

  test "show returns not found for draft role" do
    get job_application_path(slug: @draft_role.slug)
    assert_response :not_found
  end

  test "show returns not found for closed role" do
    get job_application_path(slug: @closed_role.slug)
    assert_response :not_found
  end

  test "show returns not found for internal_only role" do
    get job_application_path(slug: @internal_role.slug)
    assert_response :not_found
  end

  test "show returns not found for non-existent slug" do
    get job_application_path(slug: "non-existent-role")
    assert_response :not_found
  end

  test "show returns not found for role from another tenant" do
    get job_application_path(slug: @other_role.slug)
    assert_response :not_found
  end

  test "show includes honeypot field hidden from view" do
    get job_application_path(slug: @published_role.slug)
    assert_response :success
    assert_select "input[name='application[website]'][tabindex='-1']"
  end

  test "show includes form_loaded_at hidden field for bot timing" do
    get job_application_path(slug: @published_role.slug)
    assert_response :success
    assert_select "input[name='application[form_loaded_at]']"
  end

  test "show form has Stimulus application-form controller data attributes" do
    get job_application_path(slug: @published_role.slug)
    assert_response :success
    # Form has Stimulus controller and submit action
    assert_select "form[data-controller='application-form']"
    assert_select "form[data-action='submit->application-form#submit']"
    # Submit button has target
    assert_select "input[type='submit'][data-application-form-target='submitButton']"
    # File input has target and action for validation
    assert_select "input[type='file'][data-application-form-target='fileInput']"
    assert_select "input[type='file'][data-action='change->application-form#validateFile']"
    # File feedback targets exist
    assert_select "[data-application-form-target='fileInfo']"
    assert_select "[data-application-form-target='fileError']"
  end

  test "show form has field wrappers for client-side validation" do
    get job_application_path(slug: @published_role.slug)
    assert_response :success
    assert_select "[data-field-wrapper]", minimum: 4 # first_name, last_name, email, phone
  end

  test "show form has required attributes on mandatory fields" do
    get job_application_path(slug: @published_role.slug)
    assert_response :success
    assert_select "input[name='application[first_name]'][required]"
    assert_select "input[name='application[last_name]'][required]"
    assert_select "input[name='application[email]'][required]"
    # Phone is optional
    assert_select "input[name='application[phone]']:not([required])"
  end

  test "show form has file accept attribute restricting types" do
    get job_application_path(slug: @published_role.slug)
    assert_response :success
    assert_select "input[name='application[resume]'][accept]"
  end

  test "show form preserves field values on re-render after validation error" do
    post job_application_path(slug: @published_role.slug), params: {
      application: {
        first_name: "Jane",
        last_name: "",
        email: "jane@example.com",
        phone: "555-1234",
        cover_letter: "My cover letter text",
        form_loaded_at: 10.seconds.ago.iso8601
      }
    }

    assert_response :unprocessable_entity
    # Previously entered values should be preserved in the re-rendered form
    assert_select "input[name='application[first_name]'][value='Jane']"
    assert_select "input[name='application[email]'][value='jane@example.com']"
    assert_select "input[name='application[phone]'][value='555-1234']"
  end

  test "show form displays company name in submit disclaimer" do
    get job_application_path(slug: @published_role.slug)
    assert_response :success
    assert_select "p", /Acme Corp/
  end

  test "show form uses company brand color for submit button" do
    get job_application_path(slug: @published_role.slug)
    assert_response :success
    assert_select "input[type='submit'][style*='#E11D48']"
  end

  test "show renders additional questions section header when custom questions exist" do
    ActsAsTenant.with_tenant(@company) do
      CustomQuestion.create!(
        company: @company,
        role: @published_role,
        label: "Test question",
        field_type: "text",
        position: 0,
        required: false
      )
    end

    get job_application_path(slug: @published_role.slug)
    assert_response :success
    assert_select "h2", /Additional Questions/
  end

  test "show does not render additional questions section when no custom questions" do
    get job_application_path(slug: @published_role.slug)
    assert_response :success
    assert_select "h2", { text: /Additional Questions/, count: 0 }
  end

  test "show renders custom questions when present" do
    ActsAsTenant.with_tenant(@company) do
      CustomQuestion.create!(
        company: @company,
        role: @published_role,
        label: "Years of experience?",
        field_type: "text",
        position: 0,
        required: true
      )
      CustomQuestion.create!(
        company: @company,
        role: @published_role,
        label: "Why this role?",
        field_type: "textarea",
        position: 1,
        required: false
      )
    end

    get job_application_path(slug: @published_role.slug)
    assert_response :success
    assert_select "label", /Years of experience/
    assert_select "label", /Why this role/
  end

  test "show renders all three custom question field types dynamically" do
    ActsAsTenant.with_tenant(@company) do
      CustomQuestion.create!(
        company: @company,
        role: @published_role,
        label: "Short answer",
        field_type: "text",
        position: 0,
        required: true
      )
      CustomQuestion.create!(
        company: @company,
        role: @published_role,
        label: "Long answer",
        field_type: "textarea",
        position: 1,
        required: false
      )
      CustomQuestion.create!(
        company: @company,
        role: @published_role,
        label: "Experience level",
        field_type: "select",
        position: 2,
        required: true,
        options: ["Junior", "Mid", "Senior"]
      )
    end

    get job_application_path(slug: @published_role.slug)
    assert_response :success

    # Text field renders as input
    assert_select "input[type='text'][required]"
    # Textarea renders
    assert_select "textarea"
    # Select renders with options
    assert_select "select[required]" do
      assert_select "option", text: "Select..."
      assert_select "option", text: "Junior"
      assert_select "option", text: "Mid"
      assert_select "option", text: "Senior"
    end
    # Required marker shows on label
    assert_select "label", /Short answer \*/
    assert_select "label", /Experience level \*/
  end

  # ==========================================
  # Application submission — creates records
  # ==========================================

  test "successful submission creates candidate and application" do
    candidate_count_before = ActsAsTenant.without_tenant { Candidate.count }
    app_count_before = ActsAsTenant.without_tenant { ApplicationSubmission.count }

    post job_application_path(slug: @published_role.slug), params: {
      application: {
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com",
        phone: "555-0123",
        cover_letter: "I am very excited about this role.",
        form_loaded_at: 10.seconds.ago.iso8601
      }
    }

    assert_redirected_to job_application_success_path(slug: @published_role.slug)
    follow_redirect!
    assert_response :success

    assert_equal candidate_count_before + 1, ActsAsTenant.without_tenant { Candidate.count }
    assert_equal app_count_before + 1, ActsAsTenant.without_tenant { ApplicationSubmission.count }

    # Verify the created records
    ActsAsTenant.with_tenant(@company) do
      candidate = Candidate.find_by(email: "jane@example.com")
      assert_not_nil candidate
      assert_equal "Jane", candidate.first_name
      assert_equal "Doe", candidate.last_name
      assert_equal "555-0123", candidate.phone

      application = ApplicationSubmission.last
      assert_equal @published_role, application.role
      assert_equal candidate, application.candidate
      assert_equal "applied", application.status
      assert_equal "I am very excited about this role.", application.cover_letter
      assert_not_nil application.submitted_at
    end
  end

  test "successful submission sends confirmation email" do
    assert_enqueued_emails 1 do
      post job_application_path(slug: @published_role.slug), params: {
        application: {
          first_name: "Jane",
          last_name: "Doe",
          email: "jane@example.com",
          form_loaded_at: 10.seconds.ago.iso8601
        }
      }
    end
  end

  test "successful submission redirects to success page" do
    post job_application_path(slug: @published_role.slug), params: {
      application: {
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com",
        form_loaded_at: 10.seconds.ago.iso8601
      }
    }
    assert_redirected_to job_application_success_path(slug: @published_role.slug)
  end

  test "submission with cover letter saves it on the application" do
    post job_application_path(slug: @published_role.slug), params: {
      application: {
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com",
        cover_letter: "Here is my cover letter.",
        form_loaded_at: 10.seconds.ago.iso8601
      }
    }
    assert_redirected_to job_application_success_path(slug: @published_role.slug)

    ActsAsTenant.with_tenant(@company) do
      application = ApplicationSubmission.last
      assert_equal "Here is my cover letter.", application.cover_letter
    end
  end

  test "submission without cover letter succeeds (cover letter is optional)" do
    post job_application_path(slug: @published_role.slug), params: {
      application: {
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com",
        form_loaded_at: 10.seconds.ago.iso8601
      }
    }
    assert_redirected_to job_application_success_path(slug: @published_role.slug)

    ActsAsTenant.with_tenant(@company) do
      application = ApplicationSubmission.last
      assert_nil application.cover_letter
    end
  end

  test "submission snapshots custom question answers" do
    ActsAsTenant.with_tenant(@company) do
      @question = CustomQuestion.create!(
        company: @company,
        role: @published_role,
        label: "Years of experience?",
        field_type: "text",
        position: 0,
        required: false
      )
    end

    snapshot_count_before = ActsAsTenant.without_tenant { QuestionSnapshot.count }

    post job_application_path(slug: @published_role.slug), params: {
      application: {
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com",
        form_loaded_at: 10.seconds.ago.iso8601,
        custom_answers: {
          "custom_question_#{@question.id}" => "5 years"
        }
      }
    }

    assert_redirected_to job_application_success_path(slug: @published_role.slug)
    assert_equal snapshot_count_before + 1, ActsAsTenant.without_tenant { QuestionSnapshot.count }

    ActsAsTenant.with_tenant(@company) do
      snapshot = QuestionSnapshot.last
      assert_equal "Years of experience?", snapshot.label
      assert_equal "text", snapshot.field_type
      assert_equal "5 years", snapshot.answer
    end
  end

  test "submission with resume file attachment succeeds" do
    resume = fixture_file_upload("resume.pdf", "application/pdf")

    post job_application_path(slug: @published_role.slug), params: {
      application: {
        first_name: "Jane",
        last_name: "Doe",
        email: "jane-resume@example.com",
        form_loaded_at: 10.seconds.ago.iso8601,
        resume: resume
      }
    }
    assert_redirected_to job_application_success_path(slug: @published_role.slug)

    ActsAsTenant.with_tenant(@company) do
      application = ApplicationSubmission.last
      assert application.resume.attached?
    end
  end

  test "submission reuses existing candidate for same email" do
    ActsAsTenant.with_tenant(@company) do
      @existing_candidate = Candidate.create!(
        company: @company,
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com"
      )
    end

    candidate_count_before = ActsAsTenant.without_tenant { Candidate.count }

    post job_application_path(slug: @published_role.slug), params: {
      application: {
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com",
        form_loaded_at: 10.seconds.ago.iso8601
      }
    }

    assert_redirected_to job_application_success_path(slug: @published_role.slug)
    assert_equal candidate_count_before, ActsAsTenant.without_tenant { Candidate.count }

    ActsAsTenant.with_tenant(@company) do
      application = ApplicationSubmission.last
      assert_equal @existing_candidate, application.candidate
    end
  end

  # ==========================================
  # Validation errors
  # ==========================================

  test "submission without required fields re-renders form with errors" do
    app_count_before = ActsAsTenant.without_tenant { ApplicationSubmission.count }

    post job_application_path(slug: @published_role.slug), params: {
      application: {
        first_name: "",
        last_name: "",
        email: "",
        form_loaded_at: 10.seconds.ago.iso8601
      }
    }

    assert_response :unprocessable_entity
    assert_select "div.bg-red-50" # Error message displayed
    assert_equal app_count_before, ActsAsTenant.without_tenant { ApplicationSubmission.count }
  end

  test "submission with invalid email re-renders form with errors" do
    app_count_before = ActsAsTenant.without_tenant { ApplicationSubmission.count }

    post job_application_path(slug: @published_role.slug), params: {
      application: {
        first_name: "Jane",
        last_name: "Doe",
        email: "not-an-email",
        form_loaded_at: 10.seconds.ago.iso8601
      }
    }

    assert_response :unprocessable_entity
    assert_equal app_count_before, ActsAsTenant.without_tenant { ApplicationSubmission.count }
  end

  test "duplicate application by same candidate for same role re-renders with error" do
    # First application succeeds
    post job_application_path(slug: @published_role.slug), params: {
      application: {
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com",
        form_loaded_at: 10.seconds.ago.iso8601
      }
    }
    assert_redirected_to job_application_success_path(slug: @published_role.slug)

    app_count_after_first = ActsAsTenant.without_tenant { ApplicationSubmission.count }

    # Second application for same role fails
    post job_application_path(slug: @published_role.slug), params: {
      application: {
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com",
        form_loaded_at: 10.seconds.ago.iso8601
      }
    }

    assert_response :unprocessable_entity
    assert_equal app_count_after_first, ActsAsTenant.without_tenant { ApplicationSubmission.count }
  end

  # ==========================================
  # Bot detection
  # ==========================================

  test "honeypot filled flags application as bot" do
    post job_application_path(slug: @published_role.slug), params: {
      application: {
        first_name: "Bot",
        last_name: "User",
        email: "bot@example.com",
        website: "http://spam.com",
        form_loaded_at: 10.seconds.ago.iso8601
      }
    }
    assert_redirected_to job_application_success_path(slug: @published_role.slug)

    ActsAsTenant.with_tenant(@company) do
      application = ApplicationSubmission.last
      assert application.bot_flagged?
      assert application.honeypot_filled?
      assert_includes application.bot_reasons, "honeypot_filled"
    end
  end

  test "fast submission flags application as bot" do
    post job_application_path(slug: @published_role.slug), params: {
      application: {
        first_name: "Fast",
        last_name: "Bot",
        email: "fast@example.com",
        form_loaded_at: 1.second.ago.iso8601
      }
    }
    assert_redirected_to job_application_success_path(slug: @published_role.slug)

    ActsAsTenant.with_tenant(@company) do
      application = ApplicationSubmission.last
      assert application.bot_flagged?
      assert_includes application.bot_reasons, "too_fast"
    end
  end

  test "normal submission is not flagged as bot" do
    post job_application_path(slug: @published_role.slug), params: {
      application: {
        first_name: "Normal",
        last_name: "Human",
        email: "human@example.com",
        form_loaded_at: 10.seconds.ago.iso8601
      }
    }
    assert_redirected_to job_application_success_path(slug: @published_role.slug)

    ActsAsTenant.with_tenant(@company) do
      application = ApplicationSubmission.last
      assert_not application.bot_flagged?
    end
  end

  # ==========================================
  # Application status — always starts as applied
  # ==========================================

  test "new application starts with applied status" do
    post job_application_path(slug: @published_role.slug), params: {
      application: {
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com",
        form_loaded_at: 10.seconds.ago.iso8601
      }
    }
    assert_redirected_to job_application_success_path(slug: @published_role.slug)

    ActsAsTenant.with_tenant(@company) do
      assert_equal "applied", ApplicationSubmission.last.status
    end
  end

  # ==========================================
  # Application submission — non-published role
  # ==========================================

  test "create returns not found for draft role" do
    post job_application_path(slug: @draft_role.slug), params: {
      application: { first_name: "Jane", last_name: "Doe", email: "jane@example.com" }
    }
    assert_response :not_found
  end

  test "create returns not found for closed role" do
    post job_application_path(slug: @closed_role.slug), params: {
      application: { first_name: "Jane", last_name: "Doe", email: "jane@example.com" }
    }
    assert_response :not_found
  end

  test "create returns not found for internal_only role" do
    post job_application_path(slug: @internal_role.slug), params: {
      application: { first_name: "Jane", last_name: "Doe", email: "jane@example.com" }
    }
    assert_response :not_found
  end

  # ==========================================
  # Success page
  # ==========================================

  test "success page renders for published role" do
    get job_application_success_path(slug: @published_role.slug)
    assert_response :success
    assert_select "h1", /Application Submitted/
  end

  test "success returns not found for draft role" do
    get job_application_success_path(slug: @draft_role.slug)
    assert_response :not_found
  end

  test "success returns not found for closed role" do
    get job_application_success_path(slug: @closed_role.slug)
    assert_response :not_found
  end

  test "success returns not found for internal_only role" do
    get job_application_success_path(slug: @internal_role.slug)
    assert_response :not_found
  end

  # ==========================================
  # No authentication required
  # ==========================================

  test "application form does not require authentication" do
    get job_application_path(slug: @published_role.slug)
    assert_response :success
  end

  # ==========================================
  # Tenant isolation
  # ==========================================

  test "unknown subdomain returns not found" do
    host! "nonexistent.example.com"
    get job_application_path(slug: @published_role.slug)
    assert_response :not_found
  end

  test "cannot submit application to role from another tenant" do
    app_count_before = ActsAsTenant.without_tenant { ApplicationSubmission.count }

    post job_application_path(slug: @other_role.slug), params: {
      application: {
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com",
        form_loaded_at: 10.seconds.ago.iso8601
      }
    }

    assert_response :not_found
    assert_equal app_count_before, ActsAsTenant.without_tenant { ApplicationSubmission.count }
  end

  # ==========================================
  # Role status change after load
  # ==========================================

  test "returns not found when previously published role is closed" do
    ActsAsTenant.with_tenant(@company) do
      @published_role.update_column(:status, "closed")
    end
    get job_application_path(slug: @published_role.slug)
    assert_response :not_found
  end

  test "returns not found when previously published role is reverted to draft" do
    ActsAsTenant.with_tenant(@company) do
      @published_role.update_column(:status, "draft")
    end
    get job_application_path(slug: @published_role.slug)
    assert_response :not_found
  end

  # ==========================================
  # Rate limiting
  # ==========================================

  test "rate limiting blocks excessive submissions from same IP" do
    RateLimit.find_or_create_by!(
      key: "apply:127.0.0.1",
      window_start: Time.current.beginning_of_hour
    ).update!(count: 10)

    post job_application_path(slug: @published_role.slug), params: {
      application: {
        first_name: "Rate",
        last_name: "Limited",
        email: "ratelimited@example.com",
        form_loaded_at: 10.seconds.ago.iso8601
      }
    }
    assert_response :too_many_requests
  end

  # ==========================================
  # Application linked to correct tenant
  # ==========================================

  test "application is linked to the correct company" do
    post job_application_path(slug: @published_role.slug), params: {
      application: {
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com",
        form_loaded_at: 10.seconds.ago.iso8601
      }
    }
    assert_redirected_to job_application_success_path(slug: @published_role.slug)

    ActsAsTenant.with_tenant(@company) do
      application = ApplicationSubmission.last
      assert_equal @company.id, application.company_id
      assert_equal @company.id, application.candidate.company_id
    end
  end
end
