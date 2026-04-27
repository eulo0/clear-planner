# frozen_string_literal: true

class WorkShiftsController < ApplicationController
  layout "app_shell"

  before_action :authenticate_user!
  before_action :set_work_shift, only: %i[show edit update destroy]

  def index
    @q = params[:q].to_s.strip
    @work_shifts = current_user.work_shifts.ordered
    @work_shifts = @work_shifts.where("title ILIKE ? OR location ILIKE ? OR description ILIKE ?",
                                      "%#{@q}%", "%#{@q}%", "%#{@q}%") if @q.present?
  end

  def show
    return unless turbo_frame_request?

    partial = if request.headers["Turbo-Frame"] == "event_popover"
                "work_shifts/popover_detail"
    else
                "work_shifts/drawer_detail"
    end

    render partial: partial,
           locals: { work_shift: @work_shift, start_date: params[:start_date] }
  end

  def new
    @work_shift = current_user.work_shifts.new(color: "#34D399")
  end

  def create
    if in_draft_mode?
      current_user_draft.add_create("shift", work_shift_params.to_h)
      return render_draft_calendar_update
    end

    @work_shift = current_user.work_shifts.new(work_shift_params)

    if @work_shift.save
      redirect_to work_shifts_path, notice: "Shift created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    return unless turbo_frame_request?

    render partial: "work_shifts/drawer_edit",
           locals: { work_shift: @work_shift, start_date: params[:start_date] }
  end

  def update
    if in_draft_mode?
      current_user_draft.add_update("shift", @work_shift.id, work_shift_params.to_h)
      return render_draft_calendar_update
    end
    if @work_shift.update(work_shift_params)
      respond_to do |format|
        format.html { redirect_to dashboard_path, notice: "Shift updated." }

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
            redirect_to work_shifts_path, notice: "Shift updated.", status: :see_other
          end
        end
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }

        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "event_drawer",
            partial: "work_shifts/drawer_edit",
            locals: { work_shift: @work_shift, start_date: params[:start_date] }
          ), status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    if in_draft_mode?
      current_user_draft.add_delete("shift", @work_shift.id)
      return render_draft_calendar_update
    end

    @work_shift.destroy!

    respond_to do |format|
      format.html { redirect_to work_shifts_path, notice: "Shift deleted." }

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
          redirect_to work_shifts_path, notice: "Shift deleted.", status: :see_other
        end
      end
    end
  end

  def in_draft_mode?
    current_user_draft.present?
  end

  private

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

  def set_work_shift
    @work_shift = current_user.work_shifts.find(params[:id])
  end

  def work_shift_params
    params.require(:work_shift).permit(
      :title, :location, :start_time, :end_time, :start_date,
      :color, :description, :recurring, :repeat_until, :duration_minutes,
      repeat_days: []
    )
  end

  def parse_start_date(raw)
    raw.present? ? Date.parse(raw) : Date.current
  rescue ArgumentError
    Date.current
  end
end
