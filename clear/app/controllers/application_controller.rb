class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :username ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :username ])
  end

  def after_sign_in_path_for(resource)
    clear_draft_session!
    stored_location_for(resource) || authenticated_root_path
  end

  def after_sign_out_path_for(resource_or_scope)
    clear_draft_session!
    root_path
  end

  private

  def calendar_occurrences_for_range(range_start, range_end, draft: nil, filter: nil)
    # filter values: nil/"" = all, "events" = events only, "work_shifts" = work shifts only,
    # "courses" = all courses only, numeric string = specific course ID
    course_id        = filter.presence && filter !~ /\A(events|work_shifts|courses)\z/ ? filter : nil
    show_events      = filter.blank? || filter == "events"
    show_work_shifts = filter.blank? || filter == "work_shifts"
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
      base_work_shifts = current_user.work_shifts.active
        .where("repeat_until IS NULL OR repeat_until >= ?", range_start.to_date)

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

    result = (event_occurrences + course_occurrences + work_shift_occurrences + course_items).sort_by(&:starts_at)

    draft&.operation_count&.positive? ? draft.build_preview_occurrences(result, range_start, range_end) : result
  end

  # Exposed as a view helper so calendar partials rendered from non-dashboard
  # controllers (e.g. events#update turbo-stream) can still populate the filter
  # dropdown without an explicit local.
  def course_filter_courses
    @_course_filter_courses ||= current_user.courses.order(:title)
  end
  helper_method :course_filter_courses

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
