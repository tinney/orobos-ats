class ApplicationSubmissionService
  Result = Struct.new(:success?, :application, :errors, keyword_init: true)

  def initialize(role:, company:, params:, resume: nil)
    @role = role
    @company = company
    @params = params
    @resume = resume
  end

  def call
    ActiveRecord::Base.transaction do
      # Find or create candidate
      candidate = find_or_create_candidate!

      # Build application
      application = ApplicationSubmission.new(
        candidate: candidate,
        role: @role,
        company: @company,
        status: "applied",
        cover_letter: @params[:cover_letter].presence,
        submitted_at: Time.current
      )

      # Attach resume
      if @resume.present?
        application.resume.attach(@resume)
      end

      application.save!

      # Snapshot custom questions and answers
      snapshot_questions!(application)

      # Run bot detection
      bot_result = BotDetectionService.new(
        application: application,
        params: @params
      ).call

      application.update!(
        bot_score: bot_result.score,
        bot_flagged: bot_result.flagged,
        bot_reasons: bot_result.reasons,
        honeypot_filled: bot_result.reasons.include?("honeypot_filled")
      )

      # Send confirmation email
      CandidateMailer.confirmation(application).deliver_later

      Result.new(success?: true, application: application, errors: [])
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success?: false, application: nil, errors: e.record.errors.full_messages)
  rescue => e
    Result.new(success?: false, application: nil, errors: [e.message])
  end

  private

  def find_or_create_candidate!
    email = @params[:email].to_s.strip.downcase
    first_name = @params[:first_name].to_s.strip
    last_name = @params[:last_name].to_s.strip
    phone = @params[:phone].to_s.strip

    candidate = Candidate.find_by(company: @company, email: email)
    if candidate
      candidate.update!(first_name: first_name, last_name: last_name, phone: phone) if phone.present?
      candidate
    else
      Candidate.create!(
        company: @company,
        email: email,
        first_name: first_name,
        last_name: last_name,
        phone: phone.presence
      )
    end
  end

  def snapshot_questions!(application)
    @role.custom_questions.ordered.each do |question|
      answer_key = "custom_question_#{question.id}"
      answer = @params.dig(:custom_answers, answer_key).to_s.strip

      QuestionSnapshot.create!(
        application_id: application.id,
        custom_question_id: question.id,
        company: @company,
        label: question.label,
        field_type: question.field_type,
        required: question.required,
        options: question.options,
        answer: answer.presence
      )
    end
  end
end
