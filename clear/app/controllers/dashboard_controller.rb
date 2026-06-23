class DashboardController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!

  CALENDAR_VIEWS = %w[weekly monthly yearly daily].freeze

  def show
    @start_date       = resolve_start_date
    @calendar_filter  = params[:filter].presence
    @course_filter_id = @calendar_filter  # kept for view compatibility
    @courses          = current_user.courses.order(:title)
    @draft            = current_user_draft
    # An explicit ?view param wins; otherwise fall back to the saved preference cookie so a
    # bare /dashboard (e.g. the left-nav link) renders the user's last view server-side — no
    # client round-trip, no flash. The cookie is written client-side in calendar_view_controller.
    # The param is validated against the allow-list (same as the cookie) so a tampered/garbage
    # ?view can't drive rendering — unknown values fall through to the saved/default view.
    requested_view    = params[:view].presence
    requested_view    = nil unless CALENDAR_VIEWS.include?(requested_view)
    @view             = requested_view || saved_calendar_view

    # Lazy: only the selected view's data is computed.
    if @view == "yearly"
      build_year_calendar
    elsif @view == "daily"
      build_day_occurrences
    else
      build_week_and_month_occurrences
    end

    now = Time.current
    next_occurrences = calendar_occurrences_for_range(now, now + 7.days)
    @next_occurrence = next_occurrences.find { |o| o.starts_at > now }

    return unless turbo_frame_request?

    render partial: "dashboard/calendar_frame",
           locals: { view: @view, events: @occurrences, start_date: @start_date, draft: @draft,
                     month_events_by_date: @month_events_by_date, month_date: @month_date,
                     courses: @courses, course_filter_id: @course_filter_id,
                     year_calendar: @year_calendar }
  end

  def agenda
    @date =
      begin
        params[:date].present? ? Date.parse(params[:date]) : Date.current
      rescue ArgumentError
        Date.current
      end

    range_start = @date.beginning_of_day
    range_end   = @date.end_of_day

    @occurrences = calendar_occurrences_for_range(range_start, range_end)

    now = Time.current
    next_occurrences = calendar_occurrences_for_range(now, now + 7.days)
    @next_occurrence = next_occurrences.find { |o| o.starts_at > now }

    render "dashboard/agenda"
  end

  private

  # The saved view preference, validated against the allowed set so a tampered/garbage
  # cookie can't drive rendering. Returns nil (→ default weekly/monthly) when unset/invalid.
  def saved_calendar_view
    view = cookies[:calendar_view]
    view if CALENDAR_VIEWS.include?(view)
  end

  def resolve_start_date
    # The full-page dashboard always opens on "now"; in-frame navigation passes
    # start_date. The year view also honors start_date on a full load so a
    # specific year is bookmarkable.
    honor_param = turbo_frame_request? || params[:view] == "yearly" || params[:view] == "daily"
    if honor_param && params[:start_date].present?
      Date.parse(params[:start_date])
    else
      Date.current
    end
  rescue ArgumentError
    Date.current
  end

  def build_week_and_month_occurrences
    week_start  = @start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day
    @occurrences = calendar_occurrences_for_range(range_start, range_end, draft: @draft, filter: @calendar_filter)

    month_start = @start_date.beginning_of_month
    month_end   = @start_date.end_of_month
    @month_occurrences = calendar_occurrences_for_range(
      month_start.beginning_of_day, month_end.end_of_day, draft: @draft, filter: @calendar_filter
    )
    @month_events_by_date = group_occurrences_by_date(@month_occurrences)
    @month_date = @start_date
  end

  def build_day_occurrences
    range_start = @start_date.beginning_of_day
    range_end   = @start_date.end_of_day
    @occurrences = calendar_occurrences_for_range(range_start, range_end, draft: @draft, filter: @calendar_filter)
  end

  def build_year_calendar
    year        = @start_date.year
    range_start = Date.new(year, 1, 1).beginning_of_day
    range_end   = Date.new(year, 12, 31).end_of_day

    # Whole year, UNFILTERED (chips show full per-source counts); the filter is a
    # display concern inside YearCalendar. work_shifts_in_range keeps ended shifts.
    occurrences = calendar_occurrences_for_range(
      range_start, range_end, draft: @draft, work_shifts_in_range: true
    )
    @year_calendar = Dashboard::YearCalendar.new(
      year: year, occurrences: occurrences, courses: @courses, filter: @calendar_filter
    )
  end

  def group_occurrences_by_date(occurrences)
    grouped = Hash.new { |h, k| h[k] = [] }
    occurrences.each do |occ|
      grouped[occ.starts_at.in_time_zone.to_date] << occ
    end
    grouped
  end

  def occurrences_for_range(range_start, range_end)
    base_events = current_user.events

    non_recurring_events = base_events.where(recurring: false)
                                      .where(starts_at: range_start..range_end)

    recurring_events = base_events.where(recurring: true)
                                  .where("starts_at <= ?", range_end)
                                  .where("repeat_until >= ?", range_start.to_date)


    event_occurrences = (non_recurring_events + recurring_events).flat_map { |e| e.occurrences_between(range_start, range_end) }

    base_courses = current_user.courses
      .where("start_date <= ?", range_end.to_date)
      .where("end_date >= ?", range_start.to_date)
      .order(start_date: :asc)

    course_occurrences =
      base_courses.flat_map { |c| c.occurrences_between(range_start, range_end) }

    course_items =
      CourseItem
        .joins(:course)
        .where(courses: { user_id: current_user.id })
        .where(due_at: range_start..range_end)
        .includes(:course)

    (event_occurrences + course_occurrences + course_items.to_a)
      .sort_by(&:starts_at)
  end
end
