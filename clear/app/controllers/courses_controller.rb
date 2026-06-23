class CoursesController < ApplicationController
  include OccurrenceConvertible

  layout "app_shell"

  before_action :authenticate_user!
  before_action :set_course, only: %i[show edit update destroy update_grade_weights update_grade_calculation grades convert reschedule]

  def index
    @q = params[:q].to_s.strip
    @courses = current_user.courses.includes(:syllabuses, :course_items).order(:title)
    @courses = @courses.where("title ILIKE ? OR professor ILIKE ? OR term ILIKE ? OR location ILIKE ?",
                              "%#{@q}%", "%#{@q}%", "%#{@q}%", "%#{@q}%") if @q.present?
  end

  def show
    return unless turbo_frame_request?

    partial = if request.headers["Turbo-Frame"] == "event_popover"
                "courses/popover_detail"
    else
                "courses/drawer_detail"
    end

    render partial: partial,
           locals: { course: @course, start_date: params[:start_date], course_identifier: (@draft_temp_id || @course) }
  end

  def new
    @course = current_user.courses.new
  end

  def create
    if in_draft_mode?
      @course = current_user.courses.new(course_params)
      unless @course.valid?
        return render_draft_course_form_error(:new)
      end

      current_user_draft.add_create("course", course_params.to_h)
      return render_draft_calendar_update
    end

    @course = current_user.courses.new(course_params)

    if @course.save
      respond_to do |format|
        format.html { redirect_to course_path(@course), notice: "Course created." }

        format.turbo_stream do
          unless turbo_frame_request?
            redirect_to course_path(@course), status: :see_other
            next
          end

          start_date  = parse_start_date(params[:start_date])
          week_start  = start_date.beginning_of_week
          range_start = week_start.beginning_of_day
          range_end   = (week_start + 6.days).end_of_day

          occurrences = calendar_occurrences_for_range(range_start, range_end)

          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: occurrences, start_date: start_date, draft: current_user_draft }
            ),
            turbo_stream.replace("agenda_list", partial: "agenda/list"),
            turbo_stream.update("event_drawer", "")
          ]
        end
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }

        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "event_drawer",
            partial: "courses/drawer_edit",
            locals: { course: @course, start_date: params[:start_date] }
          ), status: :unprocessable_entity
        end
      end
    end
  end

  def edit
    return unless turbo_frame_request?

    render partial: "courses/drawer_edit", locals: { course: @course, start_date: params[:start_date], course_identifier: (@draft_temp_id || @course) }
  end

  def update
    if @draft_temp_id.present?
      @course.assign_attributes(course_params)
      unless @course.valid?
        return render_draft_course_form_error(:edit)
      end

      unless current_user_draft&.update_create("course", @draft_temp_id, course_params.to_h)
        redirect_to dashboard_path, alert: "Draft course was not found."
        return
      end

      return render_draft_calendar_update
    end

    if in_draft_mode?
      @course.assign_attributes(course_params)
      unless @course.valid?
        return render_draft_course_form_error(:edit)
      end

      current_user_draft.add_update("course", @course.id, course_params.to_h)
      return render_draft_calendar_update
    end

    if @course.update(course_params)
      respond_to do |format|
        format.html { redirect_to dashboard_path, notice: "Course updated." }

        format.turbo_stream do
          unless turbo_frame_request?
            redirect_to course_path(@course), status: :see_other
            next
          end

          start_date  = parse_start_date(params[:start_date])
          week_start  = start_date.beginning_of_week
          range_start = week_start.beginning_of_day
          range_end   = (week_start + 6.days).end_of_day

          occurrences = calendar_occurrences_for_range(range_start, range_end)

          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: occurrences, start_date: start_date, draft: current_user_draft }
            ),
            turbo_stream.replace("agenda_list", partial: "agenda/list"),
            turbo_stream.update("event_drawer", "")
          ]
        end
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }

        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "event_drawer",
            partial: "courses/drawer_edit",
            locals: { course: @course, start_date: params[:start_date] }
          ), status: :unprocessable_entity
        end
      end
    end
  end

  def grades
    @course.course_items.load
    @items_by_kind = @course.course_items
                            .sort_by { |i| i.due_at&.to_f || Float::INFINITY }
                            .group_by(&:kind)
  end

  def update_grade_weights
    weights = grade_weights_params
    total = weights.values.sum(&:to_f)
    if total > 100
      redirect_to grades_course_path(@course)
      return
    end
    if @course.update(grade_weights: weights)
      redirect_to grades_course_path(@course)
    else
      redirect_to grades_course_path(@course)
    end
  end

  def update_grade_calculation
    mode = params[:grade_calculation].to_s
    unless Course::GRADE_CALCULATION_MODES.include?(mode)
      redirect_to grades_course_path(@course)
      return
    end
    @course.update_columns(grade_calculation: mode)
    redirect_to grades_course_path(@course)
  end

  def destroy_all
    current_user.courses.destroy_all
    redirect_to courses_path, notice: "All courses deleted."
  end

  def destroy
    if @draft_temp_id.present?
      unless current_user_draft&.delete_create("course", @draft_temp_id)
        redirect_to dashboard_path, alert: "Draft course was not found."
        return
      end

      return render_draft_calendar_update
    end

    if in_draft_mode?
      current_user_draft.add_delete("course", @course.id)
      return render_draft_calendar_update
    end

    if params[:scope] == "single"
      excluded_date = parse_start_date(params[:start_date])
      @course.course_exceptions.find_or_create_by!(excluded_date: excluded_date)
    else
      @course.destroy!
    end

    respond_to do |format|
      format.html { redirect_to courses_path, notice: "Course deleted." }

      format.turbo_stream do
        unless turbo_frame_request?
          redirect_to courses_path, status: :see_other
          next
        end

        start_date  = parse_start_date(params[:start_date])
        week_start  = start_date.beginning_of_week
        range_start = week_start.beginning_of_day
        range_end   = (week_start + 6.days).end_of_day

        occurrences = calendar_occurrences_for_range(range_start, range_end)

        render turbo_stream: [
          turbo_stream.replace(
            "dashboard_calendar",
            partial: "dashboard/calendar_frame",
            locals: { events: occurrences, start_date: start_date, draft: current_user_draft }
          ),
          turbo_stream.replace("agenda_list", partial: "agenda/list"),
          turbo_stream.update("event_drawer", ""),
          turbo_stream.update("event_popover", "")
        ]
      end
    end
  end

  # Drag-to-move / bottom-edge resize of a course block on the weekly calendar.
  # Courses store a single weekly meeting time (start_time/end_time + repeat_days),
  # so every drag is a WHOLE-SERIES change — no scope prompt, no per-occurrence
  # override rows. A vertical drag/resize rewrites the meeting time; a cross-day
  # drag swaps the dragged weekday in repeat_days ("replace the dragged day").
  def reschedule
    # .to_s collapses a missing param into the unparseable case; Time.zone.parse
    # returns nil rather than raising, yielding a clean 400 on bad input.
    new_start = Time.zone.parse(params[:new_starts_at].to_s)
    new_end   = Time.zone.parse(params[:new_ends_at].to_s)
    return head :bad_request if new_start.nil? || new_end.nil?

    occ_date = parse_start_date(params[:start_date])
    attrs    = whole_series_course_attrs(occ_date, new_start, new_end)

    if in_draft_mode?
      stage_course_reschedule(attrs)
      return render_draft_reschedule_stream
    end

    @course.update!(attrs)
    render_reschedule_stream
  end

  private

  def convertible_source
    @course
  end

  def set_course
    if params[:id].to_s.start_with?("d_")
      unless in_draft_mode?
        redirect_to dashboard_path, alert: "Can't modify a created draft course outside of draft mode."
        return
      end

      op = current_user_draft&.find_create_op("course", params[:id])
      unless op
        redirect_to dashboard_path, alert: "Draft course was not found."
        return
      end

      @draft_temp_id = params[:id]
      @course = current_user.courses.new(op.fetch("data", {}))
      return
    end

    @course = current_user.courses.find(params[:id])
    apply_draft_course_update! if in_draft_mode?
  end

  def apply_draft_course_update!
    op = current_user_draft&.find_update_op("course", @course.id)
    return unless op

    @course.assign_attributes(op.fetch("data", {}))
  end

  def in_draft_mode?
    current_user_draft.present?
  end

  def render_draft_calendar_update
    draft       = current_user_draft
    start_date  = parse_start_date(params[:start_date])
    week_start  = start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day

    occurrences = calendar_occurrences_for_range(range_start, range_end, draft: draft)

    respond_to do |format|
      format.html { redirect_to dashboard_path(start_date: start_date.iso8601), notice: "Draft updated." }

      format.turbo_stream do
        unless turbo_frame_request?
          redirect_to dashboard_path(start_date: start_date.iso8601), status: :see_other
          next
        end

        render turbo_stream: [
          turbo_stream.replace(
            "dashboard_calendar",
            partial: "dashboard/calendar_frame",
            locals: { events: occurrences, start_date: start_date, draft: draft }
          ),
          turbo_stream.replace("agenda_list", partial: "agenda/list"),
          turbo_stream.update("event_drawer", ""),
          turbo_stream.update("event_popover", "")
        ]
      end
    end
  end

  def render_draft_course_form_error(template)
    respond_to do |format|
      format.html { render template, status: :unprocessable_entity }

      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "event_drawer",
          partial: "courses/drawer_edit",
          locals: { course: @course, start_date: params[:start_date], course_identifier: (@draft_temp_id || @course) }
        ), status: :unprocessable_entity
      end
    end
  end

  def parse_start_date(raw)
    raw.present? ? Date.parse(raw) : Date.current
  rescue ArgumentError
    Date.current
  end

  # Whole-series attributes for a course drag/resize. Always rewrites the meeting
  # time of day; only touches repeat_days when the block was dropped on a different
  # weekday (swap source weekday out, target weekday in). Deliberately never sets
  # meeting_days: a changed meeting_days makes the before_validation callback
  # re-derive repeat_days from its M–F-only string, which would clobber the swap
  # and silently drop any weekend day. repeat_days is the calendar's source of
  # truth; the edit form's meeting_days labels just go stale until the next save.
  def whole_series_course_attrs(occ_date, new_start, new_end)
    attrs = {
      "start_time" => new_start.strftime("%H:%M:%S"),
      "end_time"   => new_end.strftime("%H:%M:%S")
    }

    source_wday = occ_date.wday
    target_wday = new_start.to_date.wday
    if source_wday != target_wday
      days = Array(@course.repeat_days).map(&:to_i)
      attrs["repeat_days"] = (days - [ source_wday ] + [ target_wday ]).uniq.sort
    end

    attrs
  end

  # Stage a course drag as a draft op instead of writing live. A draft-created
  # course (temp id) updates its create op in place; an existing course merges into
  # any pending update op so the drag doesn't clobber other staged edits.
  def stage_course_reschedule(attrs)
    draft = current_user_draft

    if @draft_temp_id.present?
      existing = draft.find_create_op("course", @draft_temp_id)&.fetch("data", {}) || {}
      draft.update_create("course", @draft_temp_id, existing.merge(attrs))
      return
    end

    existing = draft.find_update_op("course", @course.id)&.fetch("data", {}) || {}
    draft.add_update("course", @course.id, existing.merge(attrs))
  end

  # Re-render the weekly calendar frame after a live reschedule, preserving the
  # active course filter and start_date. Courses only appear on the dashboard
  # (project calendars render events only), so there is no project branch.
  def render_reschedule_stream
    start_date  = parse_start_date(params[:start_date])
    # Daily view (dashboard-only) must re-render the single-day frame, not the default weekly
    # one — otherwise dragging/resizing a course in the day view flips it back to weekly.
    daily       = (params[:view] == "daily")
    week_start  = start_date.beginning_of_week
    range_start = daily ? start_date.beginning_of_day : week_start.beginning_of_day
    range_end   = daily ? start_date.end_of_day : (week_start + 6.days).end_of_day

    occurrences = calendar_occurrences_for_range(range_start, range_end, filter: params[:filter])

    render turbo_stream: [
      turbo_stream.replace("dashboard_calendar", partial: "dashboard/calendar_frame",
        locals: { events: occurrences, start_date: start_date, draft: nil, view: (daily ? "daily" : nil) }),
      turbo_stream.replace("agenda_list", partial: "agenda/list"),
      turbo_stream.update("event_popover", "")
    ]
  end

  # Draft counterpart: re-render the weekly frame with the staged drag previewed
  # (EDITED pill). Rendered unconditionally — the drag controller submits via fetch,
  # which sends no Turbo-Frame header, so a turbo_frame_request? guard would wrongly
  # fall through to a redirect.
  def render_draft_reschedule_stream
    draft       = current_user_draft
    start_date  = parse_start_date(params[:start_date])
    week_start  = start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day

    occurrences = calendar_occurrences_for_range(range_start, range_end, draft: draft, filter: params[:filter])

    render turbo_stream: [
      turbo_stream.replace("dashboard_calendar", partial: "dashboard/calendar_frame",
        locals: { events: occurrences, start_date: start_date, draft: draft }),
      turbo_stream.replace("agenda_list", partial: "agenda/list"),
      turbo_stream.update("event_popover", "")
    ]
  end

  def grade_weights_params
    allowed_kinds = CourseItem.kinds.keys
    raw = (params[:grade_weights]&.permit(*allowed_kinds) || {}).to_h
    raw.transform_values { |v| v.to_s.strip.empty? ? nil : v.to_f.clamp(0, 100) }.compact
  end

  def course_params
    params.require(:course).permit(
      :title,
      :term,
      :color,
      :start_date,
      :end_date,
      :start_time,
      :end_time,
      :duration_minutes,
      :professor,
      :location,
      :office,
      :office_hours,
      :description,
      repeat_days: []
    )
  end
end
