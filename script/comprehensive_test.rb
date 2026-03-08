#!/usr/bin/env ruby
# Run with: bin/rails runner test/comprehensive_test.rb

# Cleanup first
ActsAsTenant.without_tenant do
  if c = Company.find_by(subdomain: 'testco')
    InterviewParticipant.where(interview_id: Interview.where(company_id: c.id).select(:id)).delete_all
    PanelInterview.where(interview_id: Interview.where(company_id: c.id).select(:id)).delete_all
    ScorecardCategory.where(scorecard_id: Scorecard.where(company_id: c.id).select(:id)).delete_all
    Scorecard.where(company_id: c.id).delete_all
    Interview.where(company_id: c.id).delete_all
    OfferRevision.where(offer_id: Offer.where(company_id: c.id).select(:id)).delete_all
    Offer.where(company_id: c.id).delete_all
    QuestionSnapshot.where(company_id: c.id).delete_all
    CustomQuestion.where(company_id: c.id).delete_all
    TransferMarker.where(company_id: c.id).delete_all
    InterviewPhase.where(company_id: c.id).delete_all
    ApplicationSubmission.where(company_id: c.id).delete_all
    Candidate.where(company_id: c.id).delete_all
    Role.where(company_id: c.id).update_all(hiring_manager_id: nil)
    Role.where(company_id: c.id).delete_all
    User.where(company_id: c.id).delete_all
    RateLimit.delete_all
    c.delete
  end
end

company = Company.create!(name: 'TestCo', subdomain: 'testco')
ActsAsTenant.with_tenant(company) do
  admin = User.create!(company: company, first_name: 'Admin', last_name: 'User', email: 'admin@test.com', role: 'admin')
  hm = User.create!(company: company, first_name: 'Hiring', last_name: 'Manager', email: 'hm@test.com', role: 'hiring_manager')
  interviewer = User.create!(company: company, first_name: 'Inter', last_name: 'Viewer', email: 'iv@test.com', role: 'interviewer')

  # AC1: Tenant signup with reserved name validation
  result = TenantSignupService.new(company_name: 'Bad', subdomain: 'admin', admin_email: 'x@x.com', admin_first_name: 'X', admin_last_name: 'X').call
  raise "AC1 FAIL: reserved subdomain allowed" if result.success?
  puts "AC1 PASS: Reserved subdomain rejected"

  # AC2: Magic link token
  token = admin.generate_magic_link_token!
  found = User.find_by_magic_link_token(token)
  raise "AC2 FAIL: token not found" unless found == admin
  admin.consume_magic_link_token!
  raise "AC2 FAIL: token not consumed" if User.find_by_magic_link_token(token)
  puts "AC2 PASS: Magic link tokens work"

  # AC3-4: Role hierarchy
  raise "AC4 FAIL" unless admin.role_at_least?(:interviewer)
  raise "AC4 FAIL" unless admin.role_at_least?(:hiring_manager)
  raise "AC4 FAIL" unless admin.role_at_least?(:admin)
  raise "AC4 FAIL" unless hm.role_at_least?(:interviewer)
  raise "AC4 FAIL" unless hm.role_at_least?(:hiring_manager)
  raise "AC4 FAIL" if hm.role_at_least?(:admin)
  puts "AC3-4 PASS: Role hierarchy correct"

  # AC5: Admin self-removal prevention
  raise "AC5 FAIL" unless admin.sole_admin?
  puts "AC5 PASS: Sole admin detection"

  # AC6-7: Role lifecycle
  role = Role.create!(company: company, title: 'Software Engineer', status: 'draft')
  puts "AC6 PASS: Role created with " + role.interview_phases.active.count.to_s + " phases"

  # AC8: Publishing requires phase owner
  raise "AC8 FAIL: should not be publishable" if role.publishable?
  phase1 = role.interview_phases.active.first
  phase1.update!(phase_owner: hm)
  raise "AC8 FAIL: should be publishable" unless role.publishable?
  role.publish!
  puts "AC8 PASS: Publishing requires phase owner"

  # AC7: Role lifecycle transitions
  role.make_internal_only!
  role.publish!
  role.close!
  role.transition_to!('draft')
  puts "AC7 PASS: Flexible transitions"

  # Re-publish for further testing
  role.publish!

  # AC12: Custom questions
  q1 = CustomQuestion.create!(company: company, role: role, label: 'Why us?', field_type: 'textarea', required: true)
  q2 = CustomQuestion.create!(company: company, role: role, label: 'Experience level', field_type: 'select', required: false, options: ['Junior', 'Mid', 'Senior'])
  puts "AC12 PASS: Custom questions created"

  # AC12-13: Application submission
  candidate = Candidate.create!(company: company, first_name: 'Jane', last_name: 'Doe', email: 'jane@example.com', phone: '555-1234')
  app = ApplicationSubmission.create!(company: company, candidate: candidate, role: role, status: 'applied', submitted_at: Time.current)

  # AC40: Question snapshots
  QuestionSnapshot.create!(application_id: app.id, custom_question: q1, company: company, label: q1.label, field_type: q1.field_type, required: q1.required, answer: 'Because you are awesome!')
  QuestionSnapshot.create!(application_id: app.id, custom_question: q2, company: company, label: q2.label, field_type: q2.field_type, required: q2.required, options: q2.options, answer: 'Senior')
  # Modify the question - snapshots should be preserved
  q1.update!(label: 'Why do you want to join?')
  snap = QuestionSnapshot.where(application_id: app.id).order(:created_at).first
  raise "AC40 FAIL: snapshot modified (got #{snap.label})" unless snap.label == 'Why us?'
  puts "AC40 PASS: Question snapshots preserved"

  # AC14-15: Bot detection
  bot_result = BotDetectionService.new(application: app, params: { website: 'spam.com', form_loaded_at: Time.current.iso8601 }).call
  raise "AC14 FAIL: honeypot not detected" unless bot_result.flagged
  raise "AC14 FAIL: no honeypot reason" unless bot_result.reasons.include?('honeypot_filled')
  app.update!(bot_flagged: true, bot_reasons: ['honeypot_filled'], bot_score: 3)
  raise "AC15 FAIL: not a warning" unless app.bot_warning?
  app.dismiss_bot_flag!
  raise "AC15 FAIL: dismiss failed" if app.bot_warning?
  puts "AC14-15 PASS: Bot detection and dismiss"

  # AC16: Pipeline stages
  app.start_interviewing!
  raise "AC16 FAIL" unless app.status == 'interviewing'
  puts "AC16 PASS: Pipeline transitions"

  # AC17: Rejection with reason
  app.reject!(reason: 'Skills mismatch')
  raise "AC17 FAIL" unless app.rejection_reason == 'Skills mismatch'
  puts "AC17 PASS: Rejection with reason"

  # AC19: Reopen
  app.reopen!
  raise "AC19 FAIL: status not restored" unless app.status == 'interviewing'
  puts "AC19 PASS: Reopen restores previous status"

  # AC18: On-hold
  app.put_on_hold!
  raise "AC18 FAIL" unless app.status == 'on_hold'
  puts "AC18 PASS: On-hold"

  # AC25-26: Interview assignment and panel
  app.start_interviewing!
  interview = Interview.create!(company: company, application: app, interview_phase: phase1, status: 'unscheduled')
  interview.assign_interviewer!(interviewer)
  raise "AC25 FAIL" unless interview.interviewers.include?(interviewer)
  raise "AC25 FAIL" unless interview.unscheduled?
  puts "AC25 PASS: Interviewer assigned, unscheduled"

  # AC26-27: Panel and scheduling
  interview.schedule!(Time.current + 1.day)
  raise "AC26 FAIL" unless interview.scheduled?
  puts "AC26-27 PASS: Interview scheduled"

  # AC28: Interview states
  interview.complete!
  raise "AC28 FAIL" unless interview.complete?
  puts "AC28 PASS: Interview complete"

  # AC29: Scorecards
  sc = Scorecard.create!(company: company, interview: interview, user: interviewer, notes: 'Great candidate')
  ScorecardCategory.create!(scorecard: sc, name: 'Technical', rating: 4)
  ScorecardCategory.create!(scorecard: sc, name: 'Communication', rating: 5)
  raise "AC29 FAIL" unless sc.average_rating == 4.5
  puts "AC29 PASS: Scorecard with ratings"

  # AC32: Percent complete
  pct = app.percent_complete
  raise "AC32 FAIL: unexpected percent #{pct}" if pct == 0
  puts "AC32 PASS: Percent complete = #{pct}%"

  # AC33: Offers
  offer = Offer.create!(company: company, application_submission: app, created_by: hm, salary: 100000, start_date: Date.today + 30, status: 'pending')
  offer.update!(status: 'accepted', salary: 110000)
  raise "AC33 FAIL: no revision" if offer.offer_revisions.empty?
  puts "AC33 PASS: Offers with revision history (rev #{offer.revision})"

  # AC34: Linked applications
  role2 = Role.create!(company: company, title: 'Product Manager', status: 'draft')
  app2 = ApplicationSubmission.create!(company: company, candidate: candidate, role: role2, status: 'applied')
  raise "AC34 FAIL" unless app.linked_application_count == 1
  puts "AC34 PASS: Linked applications count = #{app.linked_application_count}"

  # AC20: Transfer
  role3 = Role.create!(company: company, title: 'Designer', status: 'published')
  phase3 = role3.interview_phases.active.first
  phase3.update!(phase_owner: hm)
  new_app = app.transfer_to!(role3)
  raise "AC20 FAIL: wrong role" unless new_app.role == role3
  raise "AC20 FAIL: wrong status" unless new_app.status == 'applied'
  markers = TransferMarker.where(source_role: role, candidate: candidate)
  raise "AC20 FAIL: no transfer marker" if markers.empty?
  puts "AC20 PASS: Transfer successful"

  # AC21: Hard delete
  app_id = new_app.id
  new_app.hard_delete!
  raise "AC21 FAIL" unless ApplicationSubmission.where(id: app_id).empty?
  puts "AC21 PASS: Hard delete no trace"

  # AC22: Interview phases editable with data preserved
  phase2 = role.interview_phases.active.ordered[1]
  int2 = Interview.create!(company: company, application: app2, interview_phase: phase2, status: 'unscheduled')
  new_phase = phase2.update_with_versioning(name: 'Updated Phase')
  raise "AC22 FAIL: old phase not archived" unless phase2.reload.archived?
  raise "AC22 FAIL: interview lost" if int2.reload.nil?
  puts "AC22 PASS: Phase editable with data preserved"

  # AC39: Rate limiting
  5.times { RateLimit.increment!("test:127.0.0.1") }
  raise "AC39 FAIL" unless RateLimit.exceeded?("test:127.0.0.1", limit: 5)
  puts "AC39 PASS: Rate limiting works"

  puts ""
  puts "ALL ACCEPTANCE TESTS PASSED"
end

# Cleanup
ActsAsTenant.without_tenant do
  c = Company.find_by(subdomain: 'testco')
  if c
    InterviewParticipant.where(interview_id: Interview.where(company_id: c.id).select(:id)).delete_all
    PanelInterview.where(interview_id: Interview.where(company_id: c.id).select(:id)).delete_all
    ScorecardCategory.where(scorecard_id: Scorecard.where(company_id: c.id).select(:id)).delete_all
    Scorecard.where(company_id: c.id).delete_all
    Interview.where(company_id: c.id).delete_all
    OfferRevision.where(offer_id: Offer.where(company_id: c.id).select(:id)).delete_all
    Offer.where(company_id: c.id).delete_all
    QuestionSnapshot.where(company_id: c.id).delete_all
    CustomQuestion.where(company_id: c.id).delete_all
    TransferMarker.where(company_id: c.id).delete_all
    InterviewPhase.where(company_id: c.id).delete_all
    ApplicationSubmission.where(company_id: c.id).delete_all
    Candidate.where(company_id: c.id).delete_all
    Role.where(company_id: c.id).update_all(hiring_manager_id: nil)
    Role.where(company_id: c.id).delete_all
    User.where(company_id: c.id).delete_all
    RateLimit.delete_all
    c.delete
  end
end
