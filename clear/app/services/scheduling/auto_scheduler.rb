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

    DEFAULT_RECURRING_HORIZON_DAYS = 56 # 8 weeks

    def initialize(user:, duration_minutes:, weekdays: nil, repeat_until: nil,
                   search_starts_at: nil, search_ends_at: nil,
                   work_day_start: DEFAULT_WORK_DAY_START, work_day_end: DEFAULT_WORK_DAY_END,
                   buffer_minutes: DEFAULT_BUFFER_MINUTES)
      @user = user
      @duration_minutes = duration_minutes.to_i
      @weekdays = Array(weekdays).map(&:to_i).select { |w| w.between?(0, 6) }.uniq.sort
      @repeat_until = parse_date(repeat_until)
      @search_starts_at = search_starts_at || Time.current

      @search_ends_at = search_ends_at || default_search_ends_at
      @work_day_start   = work_day_start
      @work_day_end     = work_day_end
      @buffer_minutes   = buffer_minutes
    end

    def find_slot
      return nil if @duration_minutes <= 0
      @weekdays.any? ? find_recurring_slot : find_single_slot
    end

    private

    def find_single_slot
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

    # Sweeps week by week (up to repeat_until or default horizon) for the first
    # week where a single time-of-day is open on every selected weekday.
    def find_recurring_slot
      earliest_minute = @work_day_start * 60
      latest_minute   = @work_day_end * 60 - @duration_minutes
      return nil if latest_minute < earliest_minute

      busy = busy_intervals

      max_weeks = compute_max_weeks
      week_offset = 0
      while week_offset < max_weeks
        week_dates = @weekdays.map { |wday| date_for_wday_in_week(wday, week_offset) }.compact.uniq.sort
        week_offset += 1
        next if week_dates.empty?

        slot = find_time_of_day(week_dates, busy, earliest_minute, latest_minute)
        return slot if slot
      end

      nil
    end

    def find_time_of_day(dates, busy, earliest_minute, latest_minute)
      minute = earliest_minute
      while minute <= latest_minute
        hour = minute / 60
        min  = minute % 60

        all_clear = dates.all? do |date|
          slot_start = Time.zone.local(date.year, date.month, date.day, hour, min)
          slot_end   = slot_start + @duration_minutes.minutes
          next false if slot_start < @search_starts_at
          busy.none? { |b_start, b_end| b_start < slot_end && b_end > slot_start }
        end

        if all_clear
          first = dates.first
          slot_start = Time.zone.local(first.year, first.month, first.day, hour, min)
          return Result.new(starts_at: slot_start, ends_at: slot_start + @duration_minutes.minutes)
        end

        minute += GRANULARITY_MINUTES
      end

      nil
    end

    def compute_max_weeks
      today = @search_starts_at.to_date
      end_date = @repeat_until || (today + DEFAULT_RECURRING_HORIZON_DAYS)
      diff_days = (end_date - today).to_i
      return 0 if diff_days < 0
      (diff_days / 7) + 1
    end

    def date_for_wday_in_week(wday, week_offset)
      today = @search_starts_at.to_date
      this_sunday = today - today.wday.days
      target_sunday = this_sunday + (week_offset * 7).days
      date = target_sunday + wday.days

      return nil if date < today
      if date == today
        end_of_work = Time.zone.local(today.year, today.month, today.day, @work_day_end, 0)
        return nil if @search_starts_at >= end_of_work
      end
      return nil if @repeat_until && date > @repeat_until

      date
    end

    def default_search_ends_at
      if @weekdays.any?
        end_date = @repeat_until || (@search_starts_at.to_date + DEFAULT_RECURRING_HORIZON_DAYS)
        Time.zone.local(end_date.year, end_date.month, end_date.day, 23, 59, 59)
      else
        @search_starts_at + DEFAULT_SEARCH_DAYS.days
      end
    end

    def parse_date(value)
      return nil if value.blank?
      return value if value.is_a?(Date)
      Date.parse(value.to_s)
    rescue ArgumentError
      nil
    end

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
