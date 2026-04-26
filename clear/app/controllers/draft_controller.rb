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
      render_calendar_turbo_stream(draft: draft)
    else
      flash.now[:alert] = draft.errors.full_messages.to_sentence
      render_calendar_turbo_stream(draft: current_user_draft)
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

  def exit
    clear_active_draft!
    render_calendar_turbo_stream(draft: nil)
  end

  private

  def set_draft
    @draft = current_user.calendar_drafts.find(params[:id])
  end

  def render_calendar_turbo_stream(draft:)
    start_date  = parse_start_date(params[:start_date])
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

  def parse_start_date(raw)
    raw.present? ? Date.parse(raw) : Date.current
  rescue ArgumentError
    Date.current
  end
end
