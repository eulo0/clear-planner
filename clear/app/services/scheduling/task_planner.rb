# frozen_string_literal: true

module Scheduling
  # Bridges availability Blocks and unscheduled Tasks: unions active blocks into
  # allowed time intervals, then greedily places each unscheduled+incomplete task
  # (earliest-deadline-first, no-deadline last) into the earliest slot that fits
  # before its course_item.due_at. Pure: no persistence, no AI, no draft writes.
  class TaskPlanner
    Assignment = Struct.new(:task, :starts_at, :ends_at, keyword_init: true)

    def initialize(user:, range_start:, range_end:)
      @user        = user
      @range_start = range_start
      @range_end   = range_end
    end

    def call
      active = @user.blocks.active.to_a
      if active.empty?
        return { assignments: [], unplaceable: [],
                 needs_blocks: @user.blocks.proposed.any? ? :only_proposed : :none }
      end

      allowed = active.flat_map { |b| b.occurrences_between(@range_start, @range_end) }
                      .map { |occ| [ occ.starts_at, occ.ends_at ] }
                      .sort_by(&:first)

      assignments = []
      unplaceable = []
      placed      = []          # [start, end] pairs accumulated this run
      busy        = scheduled_task_intervals
      day_load    = Hash.new(0) # Date => task-minutes placed this run, for spreading

      search_start = [ Time.current, @range_start ].max
      # Compute the user's fixed calendar-busy (events/courses/shifts) ONCE for
      # the whole run instead of re-querying per task. Buffer 0 because the
      # allowed-blocks path suppresses the buffer (see AutoScheduler#effective_buffer).
      calendar_busy = AutoScheduler.calendar_busy_for(
        user: @user, search_starts_at: search_start, search_ends_at: @range_end, buffer_minutes: 0
      )

      tasks  = sorted_tasks
      budget = daily_budget(tasks, allowed)

      tasks.each do |task|
        deadline = [ @range_end, task.course_item&.due_at ].compact.min
        extra    = placed + busy

        # Pass 1: earliest slot among days still under their task-time budget, so
        # work rolls forward day-by-day instead of stacking on the first days.
        under_budget = allowed.select { |s, _e| day_load[s.to_date] + task.duration_minutes <= budget }
        slot = under_budget.empty? ? nil : find_task_slot(task, under_budget, calendar_busy, search_start, deadline, extra)
        # Pass 2 (overflow): no under-budget day before the deadline — fall back to
        # the plain earliest slot. Identical to the pre-spread behavior, so
        # feasibility is never worse than the old greedy planner.
        slot ||= find_task_slot(task, allowed, calendar_busy, search_start, deadline, extra)

        if slot
          assignments << Assignment.new(task: task, starts_at: slot.starts_at, ends_at: slot.ends_at).to_h
          placed << [ slot.starts_at, slot.ends_at ]
          day_load[slot.starts_at.to_date] += task.duration_minutes
        else
          unplaceable << { task: task, reason: unplaceable_reason(task, allowed, deadline) }
        end
      end

      { assignments: assignments, unplaceable: unplaceable, needs_blocks: nil }
    end

    private

    def sorted_tasks
      @user.tasks.unscheduled.incomplete.includes(:course_item).to_a.sort_by do |t|
        due = t.course_item&.due_at
        [ due ? 0 : 1, due || @range_end, t.id ]
      end
    end

    # Even-spread target: total task work over the days that have availability,
    # floored at the longest single task so any task fits on an empty day. The
    # floor prevents pathological always-overflow when a far-off deadline inflates
    # the available-day count and pushes the raw average below one task.
    def daily_budget(tasks, allowed)
      return 0 if tasks.empty?
      available_days = allowed.map { |s, _e| s.to_date }.uniq.size
      available_days = 1 if available_days.zero?
      total_work   = tasks.sum(&:duration_minutes)
      longest_task = tasks.map(&:duration_minutes).max
      [ (total_work.to_f / available_days).ceil, longest_task ].max
    end

    def find_task_slot(task, allowed_intervals, calendar_busy, search_start, deadline, extra_busy)
      AutoScheduler.new(
        user:                      @user,
        duration_minutes:          task.duration_minutes,
        allowed_intervals:         allowed_intervals,
        search_starts_at:          search_start,
        search_ends_at:            deadline,
        extra_busy:                extra_busy,
        precomputed_calendar_busy: calendar_busy
      ).find_slot
    end

    def scheduled_task_intervals
      @user.tasks.scheduled.incomplete.map do |t|
        [ t.scheduled_at, t.scheduled_at + t.duration_minutes.minutes ]
      end
    end

    # Distinguishes why a task didn't fit, for user-facing feedback.
    def unplaceable_reason(task, allowed, deadline)
      return :past_deadline if deadline <= Time.current
      window = allowed.map { |s, e| ((e - s) / 60).to_i }.max || 0
      return :too_long if task.duration_minutes > window
      :no_room
    end
  end
end
