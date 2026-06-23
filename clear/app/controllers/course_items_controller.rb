# frozen_string_literal: true

class CourseItemsController < ApplicationController
  layout "app_shell"

  before_action :authenticate_user!
  before_action :set_course
  before_action :set_course_item, only: %i[show edit update destroy reschedule]

  def index
    @course_items = @course.course_items.order(:due_at)
    @course_item  = @course.course_items.new
  end

  def create
    @course_item = @course.course_items.new(course_item_params)

    if @course_item.save
      respond_to do |format|
        format.html do
          redirect_to course_course_items_path(@course), notice: "Course item created."
        end

        format.turbo_stream do
          redirect_to course_course_items_path(@course),
                      notice: "Course item created.",
                      status: :see_other
        end
      end
    else
      @course_items = @course.course_items.order(:due_at)

      respond_to do |format|
        format.html { render :index, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "new-course-item-form",
            partial: "course_items/new_item_section",
            locals: { course: @course, course_item: @course_item }
          ), status: :unprocessable_entity
        end
      end
    end
  end

  def show
    # return unless turbo_frame_request?

    # render partial: "course_items/popover_detail",
    #       locals: { course_item: @course_item, course: @course, start_date: params[:start_date] }
    return unless turbo_frame_request?

    partial = if request.headers["Turbo-Frame"] == "event_popover"
                "course_items/popover_detail"
    else
                "course_items/drawer_detail"
    end

    render partial: partial,
           locals: { course_item: @course_item, course: @course, start_date: params[:start_date] }
  end

  def edit
    return unless turbo_frame_request?

    render partial: "course_items/drawer_edit", locals: { course_item: @course_item, course: @course, start_date: params[:start_date] }
  end

  def update
    if @course_item.update(course_item_params)
      respond_to do |format|
        format.html do
          redirect_to course_course_items_path(@course), notice: "Course item updated."
        end

        format.turbo_stream do
          if turbo_frame_request?
            start_date  = parse_start_date(params[:start_date])
            week_start  = start_date.beginning_of_week
            range_start = week_start.beginning_of_day
            range_end   = (week_start + 6.days).end_of_day
            occurrences = calendar_occurrences_for_range(range_start, range_end)

            render turbo_stream: [
              turbo_stream.replace(
                "dashboard_calendar",
                partial: "dashboard/calendar_frame",
                locals: { events: occurrences, start_date: start_date }
              ),
              turbo_stream.replace("agenda_list", partial: "agenda/list"),
              turbo_stream.update("event_drawer", ""),
              turbo_stream.update("event_popover", "")
            ]
          else
            redirect_to course_course_items_path(@course),
                        notice: "Course item updated.",
                        status: :see_other
          end
        end
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "event_drawer",
            partial: "course_items/drawer_edit",
            locals: { course_item: @course_item, course: @course, start_date: params[:start_date] }
          ), status: :unprocessable_entity
        end
      end
    end
  end

  # Drag-reschedule from the weekly calendar. A course item is a single
  # point-in-time due date, so a drag moves due_at only and always applies
  # immediately (no draft staging, unlike events/courses).
  def reschedule
    # .to_s collapses a missing param into the unparseable case; Time.zone.parse
    # returns nil rather than raising, yielding a clean 400 on bad input.
    new_start = Time.zone.parse(params[:new_starts_at].to_s)
    return head :bad_request if new_start.nil?

    @course_item.update!(due_at: new_start)

    start_date  = parse_start_date(params[:start_date])
    week_start  = start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day
    occurrences = calendar_occurrences_for_range(range_start, range_end, filter: params[:filter])

    render turbo_stream: [
      turbo_stream.replace(
        "dashboard_calendar",
        partial: "dashboard/calendar_frame",
        locals: { events: occurrences, start_date: start_date }
      ),
      turbo_stream.replace("agenda_list", partial: "agenda/list"),
      turbo_stream.update("event_popover", "")
    ]
  end

  def destroy
    @course_item.destroy!

    respond_to do |format|
      format.html do
        redirect_to course_course_items_path(@course), notice: "Course item deleted."
      end

      format.turbo_stream do
        unless turbo_frame_request?
          redirect_to course_course_items_path(@course), notice: "Course item deleted.", status: :see_other
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
            locals: { events: occurrences, start_date: start_date }
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
    @course = current_user.courses.find(params[:course_id])
  end

  def set_course_item
    @course_item = @course.course_items.find(params[:id])
  end

  def course_item_params
    params.require(:course_item).permit(:title, :kind, :due_at, :details, :points_possible, :points_earned)
  end

  def parse_start_date(raw)
    raw.present? ? Date.parse(raw) : Date.current
  rescue ArgumentError
    Date.current
  end
end
