# frozen_string_literal: true

# Drives the first-login, full-screen syllabus onboarding flow:
#   show -> create (multi-file upload) -> status (poll) -> review -> confirm
# with a skip path out at any point. Everything is scoped to current_user;
# no record IDs are accepted from the URL.
class OnboardingController < ApplicationController
  layout "onboarding"
  before_action :authenticate_user!

  # Max syllabi accepted in a single onboarding batch.
  MAX_FILES = 8

  # Step 1 — welcome + drag-and-drop upload screen.
  def show
    @syllabus = current_user.syllabuses.new
  end

  # Accept multiple files, create one Syllabus per file, enqueue parsing, and
  # advance to the polling screen. Per-file isolation: a file that fails
  # validation is rejected on its own and never blocks or rolls back the
  # others — there is deliberately no wrapping transaction here.
  def create
    files = Array(params[:files]).reject(&:blank?).first(MAX_FILES)

    return upload_error("Add at least one syllabus file, or choose “I don't have one.”") if files.empty?

    created_ids = []
    rejected    = []

    files.each do |file|
      syllabus = current_user.syllabuses.new(title: file.original_filename.to_s, file: file)

      if syllabus.save
        syllabus.update!(parse_status: "queued", parse_error: nil, course_draft: {})
        SyllabusParseJob.perform_later(syllabus.id)
        created_ids << syllabus.id
      else
        rejected << file.original_filename.to_s
      end
    end

    return upload_error("We couldn't read those files. Use PDF, DOC, or DOCX under 800 KB.") if created_ids.empty?

    session[:onboarding_batch]    = created_ids
    session[:onboarding_rejected] = rejected

    if onboarding_fetch?
      render json: { ok: true }
    else
      redirect_to onboarding_status_path
    end
  end

  # "Reading your syllabus" — poll parse progress for the current batch.
  # Advances to the review screen once every file has settled (done or failed).
  def status
    @syllabuses = batch_syllabuses
    settled = @syllabuses.empty? || @syllabuses.all? { |s| s.parse_status_done? || s.parse_status_failed? }
    done    = @syllabuses.count { |s| s.parse_status_done? || s.parse_status_failed? }

    respond_to do |format|
      format.json { render json: { total: @syllabuses.size, done: done, settled: settled } }
      format.html do
        if @syllabuses.empty?
          redirect_to onboarding_path
        elsif settled
          redirect_to onboarding_review_path
        else
          @total_count = @syllabuses.size
          @done_count  = done
          @rejected    = Array(session[:onboarding_rejected])
          render :status
        end
      end
    end
  end

  # Batched, editable review of every parsed course in the current batch.
  # Required Course fields are surfaced and highlighted when the parser left
  # them blank; failed/rejected files are shown but never block the rest.
  def review
    build_previews

    if onboarding_fetch?
      # The single-page flow injects this fragment into the reveal step. A
      # 204 tells the client there was nothing to review (navigate to the app).
      return head(:no_content) if @previews.empty?

      render partial: "review_body", layout: false
      return
    end

    redirect_to onboarding_path, alert: "We couldn't read any of those syllabi. Try different files." if @previews.empty?
  end

  # Create a Course (+ its parsed CourseItems) for each reviewed syllabus.
  # Per-course isolation: a course that fails validation does not roll back or
  # block the ones that save. Onboarding only finishes once nothing is failing.
  def confirm
    submitted = params[:courses]
    if submitted.blank?
      redirect_to onboarding_review_path
      return
    end

    failed = []

    submitted.each do |syllabus_id, raw_attrs|
      syllabus = current_user.syllabuses.where(id: syllabus_id).first
      next if syllabus.nil? || syllabus.course_id.present?

      course = current_user.courses.new(mapper.remap_form_attrs(course_attrs(raw_attrs).to_h))

      if course.save
        syllabus.update!(course: course)
        create_course_items(course, syllabus)
      else
        failed << { syllabus: syllabus, course: course, missing: mapper.missing_preview_fields(course) }
      end
    end

    if failed.empty?
      added    = batch_courses
      courses  = added.size
      sessions = added.sum { |c| Array(c.repeat_days).size }
      current_user.update!(onboard_status: false)
      session.delete(:onboarding_batch)
      session.delete(:onboarding_rejected)

      if onboarding_fetch?
        render json: {
          ok: true,
          courses_label: helpers.pluralize(courses, "course"),
          sessions_label: helpers.pluralize(sessions, "weekly session")
        }
      else
        flash[:onboarding_courses]  = courses
        flash[:onboarding_sessions] = sessions
        redirect_to onboarding_done_path
      end
    else
      @previews = failed
      @failed   = []
      @rejected = []

      if onboarding_fetch?
        render partial: "review_body", layout: false, status: :unprocessable_entity
      else
        flash.now[:alert] = "A couple of courses still need their required fields (marked *) before we can add them."
        render :review, status: :unprocessable_entity
      end
    end
  end

  # "I don't have one / skip" — finish onboarding without importing.
  def skip
    current_user.update!(onboard_status: false)
    redirect_to authenticated_root_path,
                notice: "You're all set — you can import a syllabus anytime from Courses."
  end

  # Final success screen ("Your quarter is on the calendar"). Reached only via
  # the flash set by #confirm; a direct/refreshed hit falls through to the app.
  def done
    unless flash.key?(:onboarding_courses)
      redirect_to authenticated_root_path
      return
    end

    @courses_added  = flash[:onboarding_courses].to_i
    @sessions_added = flash[:onboarding_sessions].to_i
  end

  private

  # True when the request comes from the single-page flow's fetch() calls.
  def onboarding_fetch?
    request.format.json? || request.headers["X-Onboarding-Fetch"].present?
  end

  # Couldn't accept the upload: JSON for fetch, redirect for the plain form.
  def upload_error(message)
    if onboarding_fetch?
      render json: { ok: false, error: message }, status: :unprocessable_entity
    else
      redirect_to onboarding_path, alert: message
    end
  end

  # Builds @previews / @failed / @rejected for the current batch (excluding
  # syllabi already turned into a course on an earlier submit).
  def build_previews
    @previews = []
    @failed   = []

    batch_syllabuses.each do |syllabus|
      next if syllabus.course_id.present?

      if syllabus.parse_status_done?
        draft  = mapper.normalized_draft_for_form(syllabus.course_draft || {})
        course = current_user.courses.new(mapper.remap_preview_attrs(draft))
        @previews << { syllabus: syllabus, course: course, missing: mapper.missing_preview_fields(course) }
      elsif syllabus.parse_status_failed?
        @failed << syllabus
      end
    end

    @rejected = Array(session[:onboarding_rejected])
  end

  # Courses created from the current batch's syllabi (across retries).
  def batch_courses
    ids = Array(session[:onboarding_batch])
    return [] if ids.empty?

    current_user.courses.joins(:syllabuses).where(syllabuses: { id: ids }).distinct.to_a
  end

  def mapper
    Syllabuses::CourseDraftMapper
  end

  def course_attrs(raw)
    raw.permit(
      :title, :code, :term, :professor, :meeting_days, :location,
      :office, :office_hours, :start_time, :end_time, :start_date, :end_date, :color
    )
  end

  # Auto-create the parsed assignments/exams stored on the syllabus draft.
  # Items aren't edited during onboarding (they're editable later in the course
  # UI), so anything malformed is simply skipped rather than blocking the course.
  def create_course_items(course, syllabus)
    items = (syllabus.course_draft || {})["course_items"] || []

    Array(items).each do |raw|
      item = raw.with_indifferent_access
      next if item[:title].blank?

      kind = item[:kind].to_s
      next unless kind.in?(CourseItem.kinds.keys)

      course.course_items.create(
        title: item[:title],
        kind: kind,
        due_at: mapper.parse_draft_due_at(item[:due_at]),
        details: item[:details].presence
      )
    end
  end

  # The current onboarding batch, always re-scoped to current_user so a stale
  # or tampered session id can never reach another user's syllabus.
  def batch_syllabuses
    ids = Array(session[:onboarding_batch])
    return Syllabus.none if ids.empty?

    current_user.syllabuses.where(id: ids).order(:created_at)
  end
end
