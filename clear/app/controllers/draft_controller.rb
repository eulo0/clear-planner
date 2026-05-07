# frozen_string_literal: true

class DraftController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!
  before_action :set_draft, only: %i[rename destroy]

  def enter
    draft = if params[:draft_id].present?
      current_user.calendar_drafts.find_by(id: params[:draft_id])
    else
      current_user_draft || current_user_drafts.first
    end

    return render_calendar_turbo_stream(draft: current_user_draft) unless draft

    activate_draft!(draft)
    flash.now[:notice] = "You are now in draft: #{draft.name}."
    render_calendar_turbo_stream(draft: draft)
  end

  def create
    if current_user_drafts.count >= CalendarDraft::MAX_DRAFTS_PER_USER
      flash.now[:alert] = "You can only have up to #{CalendarDraft::MAX_DRAFTS_PER_USER} drafts."
      return render_calendar_turbo_stream(draft: current_user_draft)
    end

    draft = current_user.calendar_drafts.new(name: params[:name])
    if draft.save
      activate_draft!(draft)
      flash.now[:notice] = "You are now in draft #{draft.name}."
      render_calendar_turbo_stream(draft: draft)
    else
      flash.now[:alert] = draft.errors.full_messages.to_sentence
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("toast-container", partial: "shared/toasts"),
                 status: :unprocessable_entity
        end
      end
    end
  end

  def rename
    if @draft.update(name: params[:name])
      render_calendar_turbo_stream(draft: current_user_draft)
    else
      flash.now[:alert] = @draft.errors.full_messages.to_sentence
      render_calendar_turbo_stream(draft: current_user_draft)
    end
  end

  def destroy
    active = current_user_draft&.id == @draft.id
    @draft.destroy!
    @current_user_drafts = nil
    clear_active_draft! if active

    render_calendar_turbo_stream(draft: current_user_draft)
  end

  def changes
    start_date = parse_start_date(params[:start_date]).iso8601
    draft = if params[:draft_id].present?
      current_user.calendar_drafts.find_by(id: params[:draft_id])
    else
      current_user_draft
    end
    rows = draft.present? ? build_change_rows(draft.operations) : []

    render partial: "draft/changes_modal",
           locals: {
             draft: draft,
             rows: rows,
             start_date: start_date
           }
  end

  def apply
    draft = current_user_draft
    if draft
      begin
        draft.apply!(current_user)
      rescue => e
        flash.now[:alert] = "Could not apply draft: #{e.message}"
      end
      clear_active_draft!
    end

    render_calendar_turbo_stream(draft: nil)
  end

  def discard
    draft = current_user_draft
    if draft
      draft.discard!
      clear_active_draft!
    end

    render_calendar_turbo_stream(draft: nil)
  end

  def restore
    start_date = parse_start_date(params[:start_date])
    draft = current_user_draft

    if draft.present?
      idx = params[:index].to_i
      ops = draft.operations.dup
      ops.delete_at(idx) if idx >= 0 && idx < ops.length
      draft.update!(operations: ops)
    end

    render_calendar_turbo_stream(
      draft: current_user_draft,
      start_date: start_date,
      include_changes_modal: true
    )
  end

  def exit
    clear_active_draft!
    render_calendar_turbo_stream(draft: nil)
  end

  private

  def set_draft
    @draft = current_user.calendar_drafts.find(params[:id])
  end

  def render_calendar_turbo_stream(draft:, start_date: nil, include_changes_modal: false)
    start_date  = start_date || parse_start_date(params[:start_date])
    week_start  = start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day
    drafts      = current_user_drafts.to_a

    occurrences = calendar_occurrences_for_range(range_start, range_end, draft: draft)
    streams = [
      turbo_stream.replace(
        "toast-container",
        partial: "shared/toasts"
      ),
      turbo_stream.replace(
        "dashboard_calendar",
        partial: "dashboard/calendar_frame",
        locals: { events: occurrences, start_date: start_date, draft: draft }
      ),
      turbo_stream.replace(
        "draft_toggle",
        partial: "draft/toggle",
        locals: {
          start_date: start_date.iso8601,
          active_draft: draft,
          drafts: drafts,
          max_drafts: CalendarDraft::MAX_DRAFTS_PER_USER
        }
      ),
      turbo_stream.replace(
        "draft_banner",
        partial: "draft/banner",
        locals: { start_date: start_date.iso8601, active_draft: draft }
      )
    ]
    if include_changes_modal
      rows = draft.present? ? build_change_rows(draft.operations) : []
      streams << turbo_stream.replace(
        "draft_changes_modal",
        partial: "draft/changes_modal",
        locals: { draft: draft, rows: rows, start_date: start_date.iso8601 }
      )
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: streams }
    end
  end

  def activate_draft!(draft)
    session[:calendar_draft_mode] = true
    session[:active_calendar_draft_id] = draft.id
    @current_user_draft = draft
    @current_user_drafts = nil
  end

  def clear_active_draft!
    session.delete(:calendar_draft_mode)
    session.delete(:active_calendar_draft_id)
    @current_user_draft = nil
    @current_user_drafts = nil
  end

  def build_change_rows(operations)
    operations.each_with_index.map do |op, idx|
      type   = op["type"].to_s
      model  = op["model"].to_s
      data   = op["data"] || {}
      record = op["id"].present? ? draft_record_for(model, op["id"]) : nil

      {
        index: idx,
        id: op["id"] || op["temp_id"] || "op_#{idx}",
        action: type,
        model: model,
        color: data["color"].presence || record&.try(:color).presence,
        title: data["title"].presence || record&.title
      }
    end
  end

  def draft_record_for(model, id)
    case model
    when "event" then current_user.events.find_by(id: id)
    when "course" then current_user.courses.find_by(id: id)
    when "shift" then current_user.work_shifts.find_by(id: id)
    end
  end

  def parse_start_date(raw)
    raw.present? ? Date.parse(raw) : Date.current
  rescue ArgumentError
    Date.current
  end
end
