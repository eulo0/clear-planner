# frozen_string_literal: true

class TasksController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!
  before_action :set_task, only: %i[show edit update destroy reschedule]

  def index
    load_board
  end

  def new
    redirect_to tasks_path
  end

  def create
    if in_draft_mode?
      current_user_draft.add_create("task", task_params.to_h)
      redirect_to tasks_path, notice: "Task staged to draft."
      return
    end
    @task = current_user.tasks.new(task_params)
    if @task.save
      redirect_to tasks_path, status: :see_other, notice: "Task created."
    else
      load_board
      render :index, status: :unprocessable_entity
    end
  end

  def show
    render partial: "tasks/popover_detail", locals: { task: @task }
  end

  def edit
    @courses = courses_for_select
    @grouped_course_items = grouped_course_items_for_js
    return unless turbo_frame_request?
    render partial: "tasks/edit_drawer",
           locals: { task: @task, courses: @courses, grouped_course_items: @grouped_course_items }
  end

  def update
    if @draft_temp_id.present?
      current_user_draft.update_create("task", @draft_temp_id, task_params.to_h)
      respond_to do |format|
        format.turbo_stream { render_draft_calendar_stream }
        format.html { redirect_to tasks_path, notice: "Draft task updated." }
      end
      return
    end
    if in_draft_mode?
      current_user_draft.add_update("task", @task.id, task_params.to_h)
      respond_to do |format|
        format.turbo_stream { render_draft_calendar_stream }
        format.html { redirect_to tasks_path, notice: "Task update staged to draft." }
      end
      return
    end
    if @task.update(task_params)
      respond_to do |format|
        format.turbo_stream { render_task_reschedule_stream }
        format.html { redirect_to tasks_path, status: :see_other, notice: "Task updated." }
      end
    else
      render partial: "tasks/edit_drawer",
             locals: { task: @task, courses: courses_for_select, grouped_course_items: grouped_course_items_for_js },
             status: :unprocessable_entity
    end
  end

  def destroy
    if @draft_temp_id.present?
      current_user_draft.delete_create("task", @draft_temp_id)
      respond_to do |format|
        format.turbo_stream { render_draft_calendar_stream }
        format.html { redirect_to tasks_path, notice: "Draft task removed." }
      end
      return
    end
    if in_draft_mode?
      current_user_draft.add_delete("task", @task.id)
      respond_to do |format|
        format.turbo_stream { render_draft_calendar_stream }
        format.html { redirect_to tasks_path, notice: "Task removal staged to draft." }
      end
      return
    end
    @task.destroy!
    if params[:start_date].present?
      # Deleted from the calendar popover: re-render the calendar so the band is
      # removed and the popover cleared. Without this the stale band would 404 on
      # its next show request.
      respond_to do |format|
        format.turbo_stream { render_task_reschedule_stream }
        format.html { redirect_back_or_to dashboard_path, status: :see_other, notice: "Task deleted." }
      end
    else
      redirect_back_or_to tasks_path, status: :see_other, notice: "Task deleted."
    end
  end

  def toggle
    task = current_user.tasks.find(params[:id])
    if task.done?
      task.update!(done: false, completed_at: nil)
    else
      task.update!(done: true, completed_at: Time.current)
    end
    head :ok
  end

  def reschedule
    new_start    = Time.zone.parse(params[:new_starts_at].to_s)
    new_end      = Time.zone.parse(params[:new_ends_at].to_s)
    return head :bad_request if new_start.nil? || new_end.nil?

    new_duration = ((new_end - new_start) / 60).round

    if in_draft_mode?
      if @draft_temp_id.present?
        existing = current_user_draft.find_create_op("task", @draft_temp_id)&.fetch("data", {}) || {}
        current_user_draft.update_create("task", @draft_temp_id,
          existing.merge("scheduled_at" => new_start.iso8601, "duration_minutes" => new_duration))
      else
        current_user_draft.add_update("task", @task.id,
          "scheduled_at" => new_start.iso8601, "duration_minutes" => new_duration)
      end
      return render_draft_calendar_stream
    end

    @task.update!(scheduled_at: new_start, duration_minutes: new_duration)
    render_task_reschedule_stream
  end

  private

  def set_task
    if params[:id].to_s.start_with?("d_")
      unless in_draft_mode?
        redirect_to tasks_path, alert: "Can't modify a draft task outside of draft mode."
        return
      end
      op = current_user_draft&.find_create_op("task", params[:id])
      unless op
        redirect_to tasks_path, alert: "Draft task not found."
        return
      end
      @draft_temp_id = params[:id]
      @task = current_user.tasks.new(op.fetch("data", {}))
      return
    end
    @task = current_user.tasks.includes(course_item: :course).find(params[:id])
    if in_draft_mode?
      update_op = current_user_draft.operations.find { |op|
        op["type"] == "update" && op["model"] == "task" && op["id"] == @task.id
      }
      @task.assign_attributes(update_op["data"]) if update_op
    end
  end

  def in_draft_mode?
    current_user_draft.present?
  end

  def parse_start_date(raw)
    raw.present? ? Date.parse(raw) : Date.current
  rescue ArgumentError
    Date.current
  end

  def render_draft_calendar_stream
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

  def render_task_reschedule_stream
    start_date  = parse_start_date(params[:start_date])
    week_start  = start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day
    events = calendar_occurrences_for_range(range_start, range_end, draft: nil, filter: params[:filter])
    render turbo_stream: [
      turbo_stream.replace("dashboard_calendar", partial: "dashboard/calendar_frame",
        locals: { events: events, start_date: start_date, draft: nil }),
      turbo_stream.replace("agenda_list", partial: "agenda/list"),
      turbo_stream.update("event_popover", "")
    ]
  end

  def load_board
    board = Tasks::Board.new(
      current_user,
      q: params[:q],
      status: params[:status],
      course_id: params[:course_id]
    ).call

    @courses                 = board.courses
    @groups                  = board.groups
    @all_tasks               = board.all_tasks
    @missed_tasks            = board.missed_tasks
    @counts                  = board.counts
    @grouped_course_items    = grouped_course_items_for_js
  end

  def courses_for_select
    current_user.courses.order(:title).map { |c| { id: c.id.to_s, name: c.title } }
  end

  def grouped_course_items_for_js
    current_user.courses.includes(:course_items).order(:title).each_with_object({}) do |course, h|
      h[course.id.to_s] = course.course_items.sort_by(&:title).map { |ci|
        { label: ci.title, value: ci.id.to_s }
      }
    end
  end

  def task_params
    params.require(:task).permit(:title, :description, :duration_minutes, :scheduled_at, :course_item_id, :color)
  end
end
