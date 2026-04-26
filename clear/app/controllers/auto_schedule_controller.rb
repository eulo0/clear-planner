# frozen_string_literal: true

class AutoScheduleController < ApplicationController
  before_action :authenticate_user!

  def preview
    duration = params[:duration_minutes].to_i
    weekdays = Array(params[:weekdays]).map(&:to_i).select { |w| w.between?(0, 6) }.uniq.sort
    repeat_until = params[:repeat_until].presence

    if duration <= 0
      return render json: { ok: false, message: "Pick a duration first." }
    end

    slot = Scheduling::AutoScheduler.new(
      user: current_user,
      duration_minutes: duration,
      weekdays: weekdays,
      repeat_until: repeat_until
    ).find_slot

    if slot
      render json: {
        ok: true,
        starts_at: slot.starts_at.iso8601,
        ends_at: slot.ends_at.iso8601,
        formatted: format_slot(slot, weekdays)
      }
    else
      message = weekdays.any? ?
        "No time-of-day works for every selected day before the end date." :
        "No open slot found in the next 7 days."
      render json: { ok: false, message: message }
    end
  end

  private

  def format_slot(slot, weekdays)
    time_range = "#{slot.starts_at.strftime('%-l:%M %p').downcase} – #{slot.ends_at.strftime('%-l:%M %p').downcase}"

    if weekdays.any?
      day_names = weekdays.map { |w| Date::ABBR_DAYNAMES[w] }.join(", ")
      "#{day_names} at #{time_range} starting #{slot.starts_at.strftime('%a %b %-d')}"
    else
      "#{slot.starts_at.strftime('%a %b %-d')}, #{time_range}"
    end
  end
end
