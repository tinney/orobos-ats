class BotDetectionService
  MINIMUM_SUBMISSION_TIME_MS = 3000 # 3 seconds

  Result = Struct.new(:flagged, :score, :reasons, keyword_init: true)

  def initialize(application:, params:)
    @application = application
    @company = application.company
    @params = params
    @score = 0
    @reasons = []
  end

  def call
    check_honeypot
    check_submission_speed
    check_duplicate_content

    Result.new(
      flagged: @score > 0,
      score: @score,
      reasons: @reasons
    )
  end

  private

  def check_honeypot
    honeypot_value = @params[:website].to_s.strip
    if honeypot_value.present?
      @score += 3
      @reasons << "honeypot_filled"
    end
  end

  def check_submission_speed
    form_loaded_at = @params[:form_loaded_at].to_s
    return if form_loaded_at.blank?

    begin
      loaded_time = Time.zone.parse(form_loaded_at)
      duration_ms = ((Time.current - loaded_time) * 1000).to_i
      @application.submission_duration_ms = duration_ms
      @application.form_loaded_at = loaded_time

      if duration_ms < MINIMUM_SUBMISSION_TIME_MS
        @score += 2
        @reasons << "too_fast"
      end
    rescue ArgumentError
      # Invalid timestamp, skip check
    end
  end

  def check_duplicate_content
    return unless @application.candidate.present?

    existing = ApplicationSubmission.where(
      company: @company,
      role: @application.role,
      candidate: @application.candidate
    ).where.not(id: @application.id).exists?

    if existing
      @score += 2
      @reasons << "duplicate_application"
    end
  end
end
