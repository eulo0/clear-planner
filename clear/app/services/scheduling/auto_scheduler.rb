# frozen_string_literal: true

module Scheduling
  # Finds the first open slot of a given duration in a user's calendar,
  # avoiding overlap with existing events, courses, and work shifts.
  class AutoScheduler
    DEFAULT_SEARCH_DAYS    = 7
    DEFAULT_WORK_DAY_START = 8   # 8 AM
    DEFAULT_WORK_DAY_END   = 22  # 10 PM
    DEFAULT_BUFFER_MINUTES = 30
    GRANULARITY_MINUTES    = 15

    Result = Struct.new(:starts_at, :ends_at, keyword_init: true)

    def initialize(user:, duration_minutes:, search_starts_at: nil, search_ends_at: nil,
                   work_day_start: DEFAULT_WORK_DAY_START, work_day_end: DEFAULT_WORK_DAY_END,
                   buffer_minutes: DEFAULT_BUFFER_MINUTES)
      @user = user
      @duration_minutes = duration_minutes.to_i
      @search_starts_at = search_starts_at || Time.current
      @search_ends_at   = search_ends_at   || (@search_starts_at + DEFAULT_SEARCH_DAYS.days)
      @work_day_start   = work_day_start
      @work_day_end     = work_day_end
      @buffer_minutes   = buffer_minutes
    end

    def find_slot
      return nil if @duration_minutes <= 0

      candidate = round_up(@search_starts_at)
      busy = busy_intervals

      while candidate + @duration_minutes.minutes <= @search_ends_at
        candidate = snap_into_work_hours(candidate)
        slot_end = candidate + @duration_minutes.minutes

        if slot_end > end_of_work_day(candidate)
          candidate = start_of_next_work_day(candidate)
          next
        end

        conflict = busy.find { |b_start, b_end| b_start < slot_end && b_end > candidate }
        if conflict
          candidate = round_up(conflict.last)
          next
        end

        return Result.new(starts_at: candidate, ends_at: slot_end)
      end

      nil
    end

    private

    def busy_intervals
      intervals = []

      @user.events
           .where(project_id: nil)
           .where("starts_at <= ?", @search_ends_at)
           .where("recurring = FALSE OR repeat_until >= ?", @search_starts_at.to_date)
           .each do |event|
        event.occurrences_between(@search_starts_at, @search_ends_at).each do |occ|
          intervals << buffered(occ.starts_at, occ.ends_at) if occ.ends_at
        end
      end

      @user.courses
           .where("start_date <= ?", @search_ends_at.to_date)
           .where("end_date >= ?", @search_starts_at.to_date)
           .each do |course|
        course.occurrences_between(@search_starts_at, @search_ends_at).each do |occ|
          intervals << buffered(occ.starts_at, occ.ends_at) if occ.ends_at
        end
      end

      @user.work_shifts
           .active
           .where("repeat_until IS NULL OR repeat_until >= ?", @search_starts_at.to_date)
           .each do |shift|
        shift.occurrences_between(@search_starts_at, @search_ends_at).each do |occ|
          intervals << buffered(occ.starts_at, occ.ends_at) if occ.ends_at
        end
      end

      intervals.sort_by(&:first)
    end

    def buffered(starts_at, ends_at)
      [ starts_at - @buffer_minutes.minutes, ends_at + @buffer_minutes.minutes ]
    end

    def round_up(time)
      step = GRANULARITY_MINUTES.minutes
      Time.zone.at(((time.to_i + step - 1) / step) * step)
    end

    def snap_into_work_hours(time)
      if time.hour < @work_day_start
        time.change(hour: @work_day_start, min: 0)
      elsif time.hour >= @work_day_end
        start_of_next_work_day(time)
      else
        time
      end
    end

    def end_of_work_day(time)
      time.change(hour: @work_day_end, min: 0)
    end

    def start_of_next_work_day(time)
      (time + 1.day).change(hour: @work_day_start, min: 0)
    end
  end
end
