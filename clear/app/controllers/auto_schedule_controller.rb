# frozen_string_literal: true

class AutoScheduleController < ApplicationController
  before_action :authenticate_user!

  def preview
    duration = params[:duration_minutes].to_i
    weekdays = Array(params[:weekdays]).map(&:to_i).select { |w| w.between?(0, 6) }.uniq.sort
    repeat_until = params[:repeat_until].presence
    priority = params[:priority]

    if duration <= 0
      return render json: { ok: false, message: "Pick a duration first." }
    end

    result = Scheduling::AutoScheduler.new(
      user: current_user,
      duration_minutes: duration,
      priority: priority,
      weekdays: weekdays,
      repeat_until: repeat_until
    ).find_slot

    if result
      displacements = preview_displacements(result)
      render json: {
        ok: true,
        starts_at: result.starts_at.iso8601,
        ends_at: result.ends_at.iso8601,
        formatted: format_slot(result, displacements, weekdays)
      }
    else
      message = weekdays.any? ?
        "No time-of-day works for every selected day before the end date." :
        "No open slot found in the next 7 days."
      render json: { ok: false, message: message }
    end
  end

  private

  def preview_displacements(result)
    return [] if result.displaced.blank?

    extra_busy = [ [ result.starts_at, result.ends_at ] ]

    result.displaced.map do |d|
      duration = d.duration_minutes
      duration ||= ((d.ends_at - d.starts_at) / 60).to_i if d.starts_at && d.ends_at

      slot = Scheduling::AutoScheduler.new(
        user: current_user,
        duration_minutes: duration,
        priority: d.priority,
        exclude_event_id: d.id,
        allow_displacement: false,
        extra_busy: extra_busy.dup
      ).find_slot

      extra_busy << [ slot.starts_at, slot.ends_at ] if slot
      { event: d, slot: slot }
    end
  end

  def format_slot(result, displacements, weekdays)
    time_range = "#{result.starts_at.strftime('%-l:%M %p').downcase} – #{result.ends_at.strftime('%-l:%M %p').downcase}"
    base = "#{result.starts_at.strftime('%a %b %-d')}, #{time_range}"

    if weekdays.length > 1
      day_names = weekdays.map { |w| Date::ABBR_DAYNAMES[w] }.join(", ")
      base = "#{base} (repeats #{day_names})"
    end

    if displacements.any?
      parts = displacements.map do |d|
        if d[:slot]
          "'#{d[:event].title}' to #{d[:slot].starts_at.strftime('%a %b %-d')}, #{d[:slot].starts_at.strftime('%-l:%M %p').downcase}"
        else
          "'#{d[:event].title}' (no slot)"
        end
      end
      base = "#{base}; will move #{parts.join(', ')}"
    end

    base
  end
end
