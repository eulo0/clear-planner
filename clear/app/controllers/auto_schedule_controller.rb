# frozen_string_literal: true

class AutoScheduleController < ApplicationController
  before_action :authenticate_user!

  def preview
    duration = params[:duration_minutes].to_i

    if duration <= 0
      return render json: { ok: false, message: "Pick a duration first." }
    end

    slot = Scheduling::AutoScheduler.new(
      user: current_user,
      duration_minutes: duration
    ).find_slot

    if slot
      render json: {
        ok: true,
        starts_at: slot.starts_at.iso8601,
        ends_at: slot.ends_at.iso8601,
        formatted: format_slot(slot)
      }
    else
      render json: { ok: false, message: "No open slot found in the next 7 days." }
    end
  end

  private

  def format_slot(slot)
    day = slot.starts_at.strftime("%a %b %-d")
    "#{day}, #{slot.starts_at.strftime('%-l:%M %p').downcase} – #{slot.ends_at.strftime('%-l:%M %p').downcase}"
  end
end
