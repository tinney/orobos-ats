# frozen_string_literal: true

require "test_helper"

class ApplicationSubmissionTest < ActiveSupport::TestCase
  setup do
    @company = Company.create!(name: "Test Co", subdomain: "testco")
    ActsAsTenant.current_tenant = @company
    @role = Role.create!(company: @company, title: "Engineer")
    @candidate = Candidate.create!(
      company: @company,
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "valid application" do
    app = ApplicationSubmission.new(
      company: @company,
      candidate: @candidate,
      role: @role,
      status: "applied"
    )
    assert app.valid?
  end

  test "defaults to applied status" do
    app = ApplicationSubmission.create!(
      company: @company,
      candidate: @candidate,
      role: @role
    )
    assert_equal "applied", app.status
  end

  test "validates status inclusion" do
    app = ApplicationSubmission.new(
      company: @company,
      candidate: @candidate,
      role: @role,
      status: "invalid_status"
    )
    assert_not app.valid?
  end

  test "candidate can only apply once per role" do
    ApplicationSubmission.create!(company: @company, candidate: @candidate, role: @role)
    dup = ApplicationSubmission.new(company: @company, candidate: @candidate, role: @role)
    assert_not dup.valid?
    assert_includes dup.errors[:candidate_id], "has already applied for this role"
  end

  test "terminal? returns true for terminal statuses" do
    ApplicationSubmission::TERMINAL_STATUSES.each do |status|
      app = ApplicationSubmission.new(status: status)
      assert app.terminal?, "#{status} should be terminal"
    end
  end

  test "terminal? returns false for non-terminal statuses" do
    %w[applied interviewing on_hold].each do |status|
      app = ApplicationSubmission.new(status: status)
      assert_not app.terminal?, "#{status} should not be terminal"
    end
  end

  test "active scope excludes terminal statuses" do
    active_app = ApplicationSubmission.create!(company: @company, candidate: @candidate, role: @role)
    candidate2 = Candidate.create!(company: @company, first_name: "Bob", last_name: "Smith", email: "bob@example.com")
    role2 = Role.create!(company: @company, title: "Designer")
    rejected_app = ApplicationSubmission.create!(company: @company, candidate: candidate2, role: role2, status: "rejected")

    active_results = ApplicationSubmission.active
    assert_includes active_results, active_app
    assert_not_includes active_results, rejected_app
  end

  test "destroys associated interviews" do
    app = ApplicationSubmission.create!(company: @company, candidate: @candidate, role: @role)
    phase = @role.interview_phases.first
    Interview.create!(company: @company, application: app, interview_phase: phase)
    assert_difference "Interview.count", -1 do
      app.destroy!
    end
  end

  # Resume validation tests
  test "accepts PDF resume" do
    app = ApplicationSubmission.create!(company: @company, candidate: @candidate, role: @role)
    app.resume.attach(
      io: StringIO.new("fake pdf content"),
      filename: "resume.pdf",
      content_type: "application/pdf"
    )
    assert app.valid?, "PDF resume should be valid"
  end

  test "accepts Word doc resume" do
    app = ApplicationSubmission.create!(company: @company, candidate: @candidate, role: @role)
    app.resume.attach(
      io: StringIO.new("fake doc content"),
      filename: "resume.doc",
      content_type: "application/msword"
    )
    assert app.valid?, "Word doc resume should be valid"
  end

  test "accepts Word docx resume" do
    app = ApplicationSubmission.create!(company: @company, candidate: @candidate, role: @role)
    app.resume.attach(
      io: StringIO.new("fake docx content"),
      filename: "resume.docx",
      content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    )
    assert app.valid?, "Word docx resume should be valid"
  end

  test "rejects non-PDF/Word resume" do
    app = ApplicationSubmission.create!(company: @company, candidate: @candidate, role: @role)
    app.resume.attach(
      io: StringIO.new("fake image content"),
      filename: "photo.jpg",
      content_type: "image/jpeg"
    )
    assert_not app.valid?
    assert_includes app.errors[:resume], "must be a PDF or Word document"
  end

  test "rejects resume over 10MB" do
    app = ApplicationSubmission.create!(company: @company, candidate: @candidate, role: @role)
    large_content = "x" * (11 * 1024 * 1024) # 11MB
    app.resume.attach(
      io: StringIO.new(large_content),
      filename: "huge_resume.pdf",
      content_type: "application/pdf"
    )
    assert_not app.valid?
    assert_includes app.errors[:resume], "must be less than 10 MB"
  end

  test "resume is optional" do
    app = ApplicationSubmission.new(
      company: @company,
      candidate: @candidate,
      role: @role,
      status: "applied"
    )
    assert app.valid?, "Application should be valid without resume"
  end

  test "cover letter is optional" do
    app = ApplicationSubmission.new(
      company: @company,
      candidate: @candidate,
      role: @role,
      status: "applied",
      cover_letter: nil
    )
    assert app.valid?
  end
end
