class BlocksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_block, only: %i[update destroy reschedule]

  def index
    @proposed = current_user.blocks.proposed.order(:position, :id)
    @active   = current_user.blocks.active.order(:position, :id)
    @blocks   = @proposed.any? ? @proposed : @active
    @mode     = @proposed.any? ? "proposed" : "active"
  end

  def create
    # In draft mode, stage the new routine instead of committing it. It renders on
    # the calendar with a NEW pill and becomes real only when the draft is applied.
    if in_draft_mode?
      current_user_draft.add_create("block", block_params.to_h.merge("status" => "active"))
      return render_blocks_calendar_stream
    end

    block = current_user.blocks.new(block_params)
    if block.save
      respond_to do |format|
        format.turbo_stream { render_blocks_calendar_stream }
        format.html { redirect_to blocks_path, notice: "Block added." }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to blocks_path, alert: block.errors.full_messages.to_sentence }
      end
    end
  end

  def update
    if @block.update(block_params)
      redirect_to blocks_path, notice: "Block updated."
    else
      redirect_to blocks_path, alert: @block.errors.full_messages.to_sentence
    end
  end

  def destroy
    # In draft mode, stage the deletion. The band-delete JS removes the band from the
    # view immediately (head :ok), matching "deleted is deleted on the view"; the real
    # block is destroyed only on apply. Discarding the draft brings the routine back.
    if in_draft_mode?
      current_user_draft.add_delete("block", @block.id)
      return head :ok
    end

    @block.destroy
    respond_to do |format|
      format.html { redirect_to blocks_path, notice: "Block removed." }
      format.json { head :no_content }
    end
  end

  def reschedule
    # In draft mode, stage the move/resize and re-render so the band picks up an
    # EDITED pill. Live mode keeps the lightweight head :ok the drag JS optimistically
    # applies without a re-render.
    if in_draft_mode?
      data = { "start_minute" => params[:start_minute].to_i, "end_minute" => params[:end_minute].to_i }
      data["repeat_days"] = Array(params[:repeat_days]).map(&:to_i) if params[:repeat_days].present?
      current_user_draft.add_update("block", @block.id, data)
      return render_blocks_calendar_stream
    end

    @block.update!(
      start_minute: params[:start_minute].to_i,
      end_minute:   params[:end_minute].to_i,
      repeat_days:  params[:repeat_days].present? ? Array(params[:repeat_days]).map(&:to_i) : @block.repeat_days
    )
    head :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def accept
    current_user.blocks.proposed.update_all(status: "active")
    redirect_to dashboard_path, notice: "Routine saved."
  end

  def discard_proposed
    current_user.blocks.proposed.delete_all
    redirect_to blocks_path, notice: "Proposed routine discarded."
  end

  private

  def in_draft_mode?
    current_user_draft.present?
  end

  def set_block
    @block = current_user.blocks.find(params[:id])
  end

  def block_params
    params.require(:block).permit(:label, :color, :start_minute, :end_minute, :status, repeat_days: [])
  end

  def parse_start_date(raw)
    raw.present? ? Date.parse(raw) : Date.current
  rescue ArgumentError
    Date.current
  end

  def render_blocks_calendar_stream
    draft       = current_user_draft
    start_date  = parse_start_date(params[:start_date])
    week_start  = start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day
    occurrences = calendar_occurrences_for_range(range_start, range_end, draft: draft, filter: params[:filter])
    render turbo_stream: turbo_stream.replace("dashboard_calendar",
      partial: "dashboard/calendar_frame",
      locals: {
        events: occurrences,
        start_date: start_date,
        draft: draft,
        view: params[:view].presence,
        courses: current_user.courses.order(:title),
        course_filter_id: params[:filter]
      })
  end
end
