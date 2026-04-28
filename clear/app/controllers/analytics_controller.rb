class AnalyticsController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!
  before_action :set_week_range

  MAX_DAILY_MINUTES = 16 * 60 # 16-hour day = 100%

  def show
    range_start = @week_start.beginning_of_day
    range_end   = @week_end.end_of_day

    stats = compute_analytics(occurrences_for_selection("current", range_start, range_end))

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
