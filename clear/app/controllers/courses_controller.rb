class CoursesController < ApplicationController
  layout "app_shell"

  before_action :authenticate_user!
  before_action :set_course, only: %i[show edit update destroy]

  def index
    @q = params[:q].to_s.strip
    @courses = current_user.courses.includes(:syllabuses).order(:title)
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
           locals: { course: @course, start_date: params[:start_date] }
  end

  def new
    @course = current_user.courses.new
  end

  def create
    if in_draft_mode?
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

    render partial: "courses/drawer_edit", locals: { course: @course, start_date: params[:start_date] }
  end

  def update
    if in_draft_mode?
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

  def destroy
    if in_draft_mode?
      current_user_draft.add_delete("course", @course.id)
      return render_draft_calendar_update
    end

    @course.destroy!

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

  private

  def set_course
    @course = current_user.courses.find(params[:id])
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

  def parse_start_date(raw)
    raw.present? ? Date.parse(raw) : Date.current
  rescue ArgumentError
    Date.current
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
