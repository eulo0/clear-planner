class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :username ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :username ])
  end

  def after_sign_in_path_for(resource)
    clear_draft_session!
    # First-login takeover: users who haven't onboarded go straight to the
    # syllabus onboarding flow, ahead of any stored deep link.
    return onboarding_path if resource.is_a?(User) && resource.onboard_status?
    stored_location_for(resource) || authenticated_root_path
  end

  def after_sign_out_path_for(resource_or_scope)
    clear_draft_session!
    root_path
  end

  private

  # Hard-blocks a feature that was retired from the left nav: any direct visit is
  # bounced to the app root. Controllers opt in via a before_action. Pass
  # `unless: :turbo_frame_request?` to keep an embedded frame (e.g. the agenda
  # list refreshed after a convert) working while blocking full-page access.
  def redirect_removed_feature
    redirect_to authenticated_root_path
  end

  def calendar_occurrences_for_range(range_start, range_end, draft: nil, filter: nil, work_shifts_in_range: false)
    # filter values: nil/"" = all, "events" = events only, "work_shifts" = work shifts only,
    # "courses" = all courses only, numeric string = specific course ID
    course_id        = filter.presence && filter !~ /\A(events|work_shifts|courses)\z/ ? filter : nil
    show_events      = filter.blank? || filter == "events"
    # Work shifts were stripped from the UI entirely — never surface them on the
    # calendar, agenda, or analytics, regardless of filter. The model/data stay.
    show_work_shifts = false
    show_courses     = filter.blank? || filter == "courses" || course_id.present?

    if show_events
      base_events = current_user.events
        .where(project_id: nil)
        .where("starts_at <= ?", range_end)
        .where("recurring = FALSE OR repeat_until >= ?", range_start.to_date)
        .order(starts_at: :asc)

      event_occurrences =
        base_events.flat_map { |e| e.occurrences_between(range_start, range_end) }
    else
      event_occurrences = []
    end

    if show_work_shifts
      base_work_shifts = current_user.work_shifts
      # The default .active scope filters by Date.current, which hides shifts that
      # have already ended. The year view opts into range-overlap instead so past
      # (and earlier-this-year) shifts still appear; weekly/monthly keep .active.
      base_work_shifts = base_work_shifts.active unless work_shifts_in_range
      base_work_shifts = base_work_shifts.where("repeat_until IS NULL OR repeat_until >= ?", range_start.to_date)

      work_shift_occurrences =
        base_work_shifts.flat_map { |ws| ws.occurrences_between(range_start, range_end) }
    else
      work_shift_occurrences = []
    end

    if show_courses
      courses_scope = current_user.courses
        .where("start_date <= ?", range_end.to_date)
        .where("end_date >= ?", range_start.to_date)
        .order(start_date: :asc)
      courses_scope = courses_scope.where(id: course_id) if course_id.present?

      course_occurrences =
        courses_scope.flat_map { |c| c.occurrences_between(range_start, range_end) }

      course_items_scope =
        CourseItem
          .joins(:course)
          .where(courses: { user_id: current_user.id })
          .where(due_at: range_start..range_end)
          .includes(:course)
      course_items_scope = course_items_scope.where(courses: { id: course_id }) if course_id.present?

      course_items = course_items_scope.to_a
    else
      course_occurrences = []
      course_items       = []
    end

    # Tasks only appear in the default "all" view; per-filter support is deferred to Phase 2.
    if filter.blank?
      task_occurrences =
        current_user.tasks.scheduled
          .where("scheduled_at <= ?", range_end)
          .where("scheduled_at + (duration_minutes * interval '1 minute') >= ?", range_start)
          .flat_map { |t| t.occurrences_between(range_start, range_end) }
    else
      task_occurrences = []
    end

    result = (event_occurrences + course_occurrences + work_shift_occurrences + course_items + task_occurrences).sort_by(&:starts_at)

    draft&.operation_count&.positive? ? draft.build_preview_occurrences(result, range_start, range_end) : result
  end

  def group_blocked_intervals(project, start_date)
    week_start = start_date.beginning_of_week
    Scheduling::GroupBlockedTimes.new(
      project: project,
      range_start: week_start.beginning_of_day,
      range_end: (week_start + 6.days).end_of_day
    ).intervals
  end

  # Exposed as a view helper so calendar partials rendered from non-dashboard
  # controllers (e.g. events#update turbo-stream) can still populate the filter
  # dropdown without an explicit local.
  def course_filter_courses
    @_course_filter_courses ||= current_user.courses.order(:title)
  end
  helper_method :course_filter_courses

  # Active availability blocks for the PERSONAL calendar only (never group/project
  # calendars, which set @project). Loaded here — not in a single controller action —
  # so the hatch bands render in every calendar path: the dashboard show AND the
  # drag/reschedule turbo-stream re-renders from EventsController/TasksController.
  def calendar_availability_blocks
    return [] if @project.present?
    @_calendar_availability_blocks ||= (current_user&.blocks&.active&.to_a || [])
  end
  helper_method :calendar_availability_blocks

  # Availability routines as the calendar band layer should render them: the active
  # blocks, merged with any block ops staged in the current draft (moved/resized get
  # a draft_status, staged-deleted are dropped, draft-created are proxies). When no
  # draft is active this is just calendar_availability_blocks. Personal calendar only.
  def draft_availability_blocks
    return [] if @project.present?
    blocks = calendar_availability_blocks
    draft  = current_user_draft
    return blocks unless draft
    draft.build_block_preview(blocks)
  end
  helper_method :draft_availability_blocks

  # For showing all the different draft options
  def current_user_drafts
    @current_user_drafts ||= current_user.calendar_drafts.recent
  end
  helper_method :current_user_drafts

  # Whenever a draft is active
  def current_user_draft
    return @current_user_draft if defined?(@current_user_draft)

    return nil unless session[:active_calendar_draft_id].present?

    draft = current_user.calendar_drafts.find_by(id: session[:active_calendar_draft_id])
      if draft.nil?
        clear_draft_session!
      else
        session[:calendar_draft_mode] = true
        @current_user_draft = draft
      end
    @current_user_draft
  end
  helper_method :current_user_draft

  def clear_draft_session!
    session.delete(:calendar_draft_mode)
    session.delete(:active_calendar_draft_id)
  end
end
