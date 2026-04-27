# frozen_string_literal: true

class EventsController < ApplicationController
  include Pagy::Method

  layout "app_shell"

  before_action :authenticate_user!
  before_action :set_event, only: %i[show edit update destroy]

  def index
    @q = params[:q].to_s.strip
    events = current_user.events.order(starts_at: :asc)
    events = events.where("title ILIKE ?", "%#{@q}%") if @q.present?
    @pagy, @events = pagy(events, limit: 10)
  end

  def show
    return unless turbo_frame_request?

    partial = if request.headers["Turbo-Frame"] == "event_popover"
                "events/popover_detail"
    else
                "events/drawer_detail"
    end

    render partial: partial,
           locals: { event: @event, start_date: params[:start_date] }
  end

  def new
    start_time = params[:start_time].present? ? Time.zone.parse(params[:start_time]) : nil
    @event = current_user.events.new(starts_at: start_time)

    if params[:project_id].present?
      @project = current_user.projects.find(params[:project_id])
      @event.project = @project
    end
  end

  def create
    if in_draft_mode?
      current_user_draft.add_create("event", event_params.to_h)
      return render_draft_calendar_update
    end

    @event = current_user.events.new(event_params)
    if params[:event][:project_id].present?
      @event.project = current_user.projects.find(params[:event][:project_id])
    end

    if @event.auto_schedule? && !apply_auto_schedule(@event)
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "event_drawer",
            partial: "events/drawer_edit",
            locals: { event: @event, start_date: params[:start_date] }
          ), status: :unprocessable_entity
        end
      end
      return
    end

    if save_event_with_displacement(@event)
      respond_to do |format|
        format.html { redirect_to event_path(@event), notice: "Event created." }

        format.turbo_stream do
          unless turbo_frame_request?
            redirect_to event_path(@event), status: :see_other
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
              locals: { events: occurrences, start_date: start_date, draft: nil }
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
            partial: "events/drawer_edit",
            locals: { event: @event, start_date: params[:start_date] }
          ), status: :unprocessable_entity
        end
      end
    end
  end

  def edit
    return unless turbo_frame_request?

    render partial: "events/drawer_edit",
           locals: { event: @event, start_date: params[:start_date] }
  end

  def update
    project = @event.project
    if in_draft_mode?
      current_user_draft.add_update("event", @event.id, event_params.to_h)
      return render_draft_calendar_update
    end

    if @event.update(event_params)
      respond_to do |format|
        if project.present?
          format.html { redirect_to project_path(project), notice: "Event updated." }
        else
          format.html { redirect_to dashboard_path, notice: "Event updated." }
        end


        format.turbo_stream do
          unless turbo_frame_request?
            redirect_to event_path(@event), status: :see_other
            next
          end

          start_date  = parse_start_date(params[:start_date])
          week_start  = start_date.beginning_of_week
          range_start = week_start.beginning_of_day
          range_end   = (week_start + 6.days).end_of_day
          occurrences = calendar_occurrences_for_range(range_start, range_end)

          if project.present?
          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: project.occurrences, start_date: start_date, draft: nil }
            ),
            turbo_stream.replace("agenda_list", partial: "agenda/list"),
            turbo_stream.update("event_drawer", ""),
            turbo_stream.update("event_popover", "")
          ]
          else
          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: occurrences, start_date: start_date, draft: nil }
            ),
            turbo_stream.replace("agenda_list", partial: "agenda/list"),
            turbo_stream.update("event_drawer", ""),
            turbo_stream.update("event_popover", "")
          ]
          end
        end
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }

        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "event_drawer",
            partial: "events/drawer_edit",
            locals: { event: @event, start_date: params[:start_date] }
          ), status: :unprocessable_entity
        end
      end
    end
  end

  def destroy_all
    current_user.events.destroy_all
    redirect_to events_path, notice: "All events deleted."
  end

  def destroy
    project =  @event.project
    if in_draft_mode?
      current_user_draft.add_delete("event", @event.id)
      return render_draft_calendar_update
    end

    if @event.recurring? && params[:scope] == "single"
      excluded_date = parse_start_date(params[:start_date])
      @event.event_exceptions.find_or_create_by!(excluded_date: excluded_date)
      notice = "This occurrence was removed."
    else
      @event.destroy!
      notice = "Event deleted."
    end

    respond_to do |format|
      format.html { redirect_to events_path, notice: notice }

      format.turbo_stream do
        unless turbo_frame_request?
          redirect_to events_path, status: :see_other
          next
        end

        start_date  = parse_start_date(params[:start_date])
        week_start  = start_date.beginning_of_week
        range_start = week_start.beginning_of_day
        range_end   = (week_start + 6.days).end_of_day
        occurrences = calendar_occurrences_for_range(range_start, range_end)

        if project.present?
          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: project.occurrences_for_week(start_date), start_date: start_date, draft: nil }
            ),
            turbo_stream.replace("agenda_list", partial: "agenda/list"),
            turbo_stream.update("event_drawer", ""),
            turbo_stream.update("event_popover", "")
          ]
        else
          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: occurrences, start_date: start_date, draft: nil }
            ),
            turbo_stream.replace("agenda_list", partial: "agenda/list"),
            turbo_stream.update("event_drawer", ""),
            turbo_stream.update("event_popover", "")
          ]
        end
      end
    end
  end

  private

  def set_event
    @event = current_user.events.find(params[:id])
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

  def event_params
    params.require(:event).permit(
      :title, :starts_at, :ends_at, :duration_minutes, :location, :priority,
      :description, :color, :recurring, :repeat_until, :project_id, :auto_schedule,
      repeat_days: []
    )
  end

  def apply_auto_schedule(event)
    recurring = event.recurring?
    weekdays = recurring ? Array(event.repeat_days).map(&:to_i) : []
    repeat_until = recurring ? event.repeat_until : nil

    result = Scheduling::AutoScheduler.new(
      user: current_user,
      duration_minutes: event.duration_minutes,
      priority: event.priority,
      weekdays: weekdays,
      repeat_until: repeat_until,
      buffer_minutes: Scheduling::AutoScheduler.buffer_for_priority(event.priority)
    ).find_slot

    if result
      event.starts_at = result.starts_at
      event.ends_at   = result.ends_at
      @displaced_events = result.displaced
      true
    else
      message = weekdays.any? ?
        "No time-of-day works for every selected day before the end date. Try fewer days, a shorter duration, a later end date, or pick a time manually." :
        "No open slot found in the next 7 days for that duration. Try a shorter duration or pick a time manually."
      event.errors.add(:base, message)
      false
    end
  end

  def save_event_with_displacement(event)
    saved = false
    ActiveRecord::Base.transaction do
      if event.save
        cascade_ok = true
        Array(@displaced_events).each do |d|
          new_slot = reschedule_displaced(d)
          if new_slot.nil?
            event.errors.add(:base, "Couldn't reschedule '#{d.title}' to make room — try a lower priority or different duration.")
            cascade_ok = false
            break
          end
          unless d.update(starts_at: new_slot.starts_at, ends_at: new_slot.ends_at)
            event.errors.add(:base, "Couldn't reschedule '#{d.title}': #{d.errors.full_messages.join(', ')}")
            cascade_ok = false
            break
          end
        end
        saved = cascade_ok
        raise ActiveRecord::Rollback unless cascade_ok
      end
    end
    saved
  end

  def reschedule_displaced(event)
    duration = event.duration_minutes
    duration ||= ((event.ends_at - event.starts_at) / 60).to_i if event.starts_at && event.ends_at

    Scheduling::AutoScheduler.new(
      user: current_user,
      duration_minutes: duration,
      priority: event.priority,
      buffer_minutes: Scheduling::AutoScheduler.buffer_for_priority(event.priority),
      exclude_event_id: event.id,
      allow_displacement: false
    ).find_slot
  end
end
