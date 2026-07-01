class AnalyticsController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!
  before_action :set_week_range

  MAX_DAILY_MINUTES = 16 * 60 # 16-hour day = 100%
  STRESS_NORMALIZATION_CAP = 3.0 # 3 deadlines at max proximity = 100% stress

  def show
    range_start = @week_start.beginning_of_day
    range_end   = @week_end.end_of_day

    current_occurrences = occurrences_for_selection("current", range_start, range_end)
    stats = compute_analytics(current_occurrences)

    @event_count        = stats[:event_count]
    @course_count       = stats[:course_count]
    @shift_count        = stats[:shift_count]
    @deadline_count     = stats[:deadline_count]
    @total_count        = stats[:total_count]
    @events_past        = stats[:events_past]
    @events_upcoming    = stats[:events_upcoming]
    @courses_past       = stats[:courses_past]
    @courses_upcoming   = stats[:courses_upcoming]
    @shifts_past        = stats[:shifts_past]
    @shifts_upcoming    = stats[:shifts_upcoming]
    @deadlines_past     = stats[:deadlines_past]
    @deadlines_upcoming = stats[:deadlines_upcoming]
    @daily_stats        = stats[:daily_stats]
    @total_minutes      = stats[:total_minutes]
    @busiest_day        = stats[:busiest_day]
    @chart_segments     = stats[:chart_segments]

    if current_user_draft&.operation_count&.positive?
      @draft_stats = compute_analytics(occurrences_for_selection(current_user_draft.id.to_s, range_start, range_end))
      @draft_name  = current_user_draft.name
    end

    @stress_data = compute_stress_scores
    @stress_peak = compute_stress_peak(@stress_data)

    tasks       = weekly_tasks
    @task_count = tasks.size
    done        = tasks.count(&:done)
    @completion = { done: done, total: tasks.size,
                    pct: tasks.empty? ? 0 : (done.to_f / tasks.size * 100).round }

    @up_next = compute_up_next(current_occurrences)
  end

  def compare
    range_start = @week_start.beginning_of_day
    range_end   = @week_end.end_of_day

    @all_drafts  = current_user_drafts.to_a
    @left_id     = params[:left].presence  || "current"
    @right_id    = params[:right].presence || (@all_drafts.first&.id&.to_s || "current")
    @left_label  = label_for(@left_id,  @all_drafts)
    @right_label = label_for(@right_id, @all_drafts)

    @left_stats  = compute_analytics(occurrences_for_selection(@left_id,  range_start, range_end))
    @right_stats = compute_analytics(occurrences_for_selection(@right_id, range_start, range_end))
  end

  private

  def set_week_range
    @week_start = Date.current.beginning_of_week
    @week_end   = Date.current.end_of_week
    @days       = (@week_start..@week_end).to_a
  end

  # Tasks relevant to the current week: scheduled within the week, OR
  # unscheduled but linked to a deadline (CourseItem) due this week.
  def weekly_tasks
    @weekly_tasks ||= begin
      range = @week_start.beginning_of_day..@week_end.end_of_day
      scheduled = Task.where(user_id: current_user.id, scheduled_at: range)
      deadline_linked = Task.where(user_id: current_user.id, scheduled_at: nil)
                            .joins(:course_item)
                            .where(course_items: { due_at: range })
      (scheduled.to_a + deadline_linked.to_a).uniq(&:id)
    end
  end

  def compute_up_next(occurrences, limit: 6)
    now       = Time.current
    range_end = @week_end.end_of_day
    rows = []

    occurrences.each do |o|
      next unless o.starts_at && o.starts_at > now && o.starts_at <= range_end
      rows << case o
              when CourseItem
                { at: o.starts_at, title: o.title,
                  subtitle: "#{o.course.title} · Deadline", type: :deadline }
              when Course::Occurrence
                { at: o.starts_at, title: o.title, subtitle: "Course", type: :course }
              when Event::Occurrence
                { at: o.starts_at, title: o.title, subtitle: "Event", type: :event }
              when WorkShift::Occurrence
                { at: o.starts_at, title: o.title, subtitle: "Work shift", type: :event }
              end
    end

    Task.where(user_id: current_user.id, scheduled_at: now..range_end)
        .includes(course_item: :course).find_each do |t|
      label = t.course_item&.course&.title || "Task"
      rows << { at: t.scheduled_at, title: t.title, subtitle: "#{label} · Task", type: :task }
    end

    rows.compact.sort_by { |r| r[:at] }.first(limit)
  end

  # The worst stress day + the deadlines/tasks driving it (due within 7 days
  # of that day). Returns nil when there is no stress to show.
  def compute_stress_peak(stress_data)
    return nil if stress_data.blank?
    peak = stress_data.max_by { |s| s[:score] }
    return nil if peak[:score].to_i.zero?

    items = CourseItem.joins(:course)
                      .where(courses: { user_id: current_user.id })
                      .where(due_at: peak[:date].beginning_of_day..(peak[:date] + 7.days).end_of_day)
                      .includes(:tasks, :course)
                      .order(:due_at)

    rows = []
    items.each do |ci|
      if ci.tasks.any?
        ci.tasks.each do |t|
          rows << { title: t.title, course: ci.course.title, due: ci.due_at.to_date,
                    needs: t.duration_minutes, planned: t.scheduled? }
        end
      else
        rows << { title: ci.title, course: ci.course.title, due: ci.due_at.to_date,
                  needs: nil, planned: nil }
      end
    end

    { date: peak[:date], score: peak[:score], rows: rows.first(4) }
  end

  def label_for(selection_id, drafts)
    return "Current Calendar" if selection_id == "current"
    drafts.find { |d| d.id.to_s == selection_id }&.name || "Unknown"
  end

  def occurrences_for_selection(selection_id, range_start, range_end)
    if selection_id == "current"
      calendar_occurrences_for_range(range_start, range_end)
    else
      draft = current_user.calendar_drafts.find_by(id: selection_id)
      return calendar_occurrences_for_range(range_start, range_end) unless draft

      raw = calendar_occurrences_for_range(range_start, range_end, draft: draft)
      raw.reject { |o| o.respond_to?(:draft_status) && o.draft_status == "deleted" }
    end
  end

  def compute_stress_scores
    # Fetch all CourseItems for the current user with due dates within the
    # stress window (week start through week end + 7 days). A single query
    # avoids N+1 per day.
    window_end = (@week_end + 7.days).end_of_day
    items = CourseItem
              .joins(:course)
              .where(courses: { user_id: current_user.id })
              .where.not(due_at: nil)
              .where(due_at: Date.current.beginning_of_day..window_end)
              .to_a

    @days.map do |day|
      window_start = day
      window_close = day + 7.days

      relevant = items.select { |item| item.due_at.to_date.between?(window_start, window_close) }

      raw_sum = relevant.sum do |item|
        days_until_due = (item.due_at.to_date - day).to_i.clamp(0, 7) # overdue items treated as max proximity
        1.0 - (days_until_due / 7.0)
      end

      score          = [ ((raw_sum / STRESS_NORMALIZATION_CAP) * 100), 100 ].min.round
      deadline_count = items.count { |item| item.due_at.to_date == day }

      { date: day, score: score, deadline_count: deadline_count }
    end
  end

  def compute_analytics(occurrences)
    now = Time.current

    events    = occurrences.select { |o| o.is_a?(Event::Occurrence) }
    courses   = occurrences.select { |o| o.is_a?(Course::Occurrence) }
    shifts    = occurrences.select { |o| o.is_a?(WorkShift::Occurrence) }
    deadlines = occurrences.select { |o| o.is_a?(CourseItem) }

    daily_stats = @days.map do |day|
      timed_occs    = occurrences.select { |o| !o.is_a?(CourseItem) && o.starts_at.to_date == day }
      timed_minutes = timed_occs.sum { |o| o.ends_at && o.starts_at ? [ (o.ends_at - o.starts_at) / 60.0, 0 ].max.to_i : 0 }
      day_deadlines = occurrences.count { |o| o.is_a?(CourseItem) && o.starts_at.to_date == day }
      {
        date:       day,
        minutes:    timed_minutes,
        item_count: timed_occs.count,
        deadlines:  day_deadlines,
        pct:        [ (timed_minutes.to_f / MAX_DAILY_MINUTES * 100), 100 ].min.round(1)
      }
    end

    total_minutes = daily_stats.sum { |s| s[:minutes] }

    {
      event_count:        events.count,
      course_count:       courses.count,
      shift_count:        shifts.count,
      deadline_count:     deadlines.count,
      total_count:        occurrences.count,
      events_past:        events.count    { |o| o.starts_at < now },
      events_upcoming:    events.count    { |o| o.starts_at >= now },
      courses_past:       courses.count   { |o| o.starts_at < now },
      courses_upcoming:   courses.count   { |o| o.starts_at >= now },
      shifts_past:        shifts.count    { |o| o.starts_at < now },
      shifts_upcoming:    shifts.count    { |o| o.starts_at >= now },
      deadlines_past:     deadlines.count { |o| o.starts_at < now },
      deadlines_upcoming: deadlines.count { |o| o.starts_at >= now },
      daily_stats:        daily_stats,
      total_minutes:      total_minutes,
      busiest_day:        daily_stats.max_by { |s| s[:minutes] },
      chart_segments:     [
        { label: "Events",      count: events.count,    color: "#60a5fa" },
        { label: "Courses",     count: courses.count,   color: "#34d399" },
        { label: "Work Shifts", count: shifts.count,    color: "#a78bfa" },
        { label: "Deadlines",   count: deadlines.count, color: "#fbbf24" }
      ].reject { |s| s[:count].zero? }
    }
  end
end
