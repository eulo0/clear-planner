class AgendaController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!
  include Pagy::Method

  def index
    session[:agenda_index_url] = request.fullpath

    @target_date = params[:date].present? ? Date.parse(params[:date]) : Date.current

    start_date =
      if params[:start_date].present?
        Date.parse(params[:start_date])
      else
        @target_date
      end

    end_date =
      if params[:end_date].present?
        Date.parse(params[:end_date])
      else
        start_date
      end

    if end_date < start_date
      flash.now[:alert] = "End date must be on or after the start date"
      end_date = start_date
      if turbo_frame_request?
        render turbo_stream: turbo_stream.replace("toast-container", partial: "shared/toasts", locals: { notice: nil, alert: flash.now[:alert] })
        return
      end
    end

    @date_range = start_date..end_date

    range_start = start_date.beginning_of_day
    range_end   = end_date.end_of_day

    occurrences = occurrences_for_range(range_start, range_end)

    agenda_by_date = occurrences.sort_by(&:starts_at)
                                .group_by { |occ| occ.starts_at.to_date }
                                .transform_values { |occs| occs.map { |occ| agenda_entry_for(occ) } }

    @type_param = params[:type]

    all_entries = agenda_by_date.values.flatten.sort_by { |e| e[:time_sortable] }

    @pagy, page_entries = pagy(:offset, all_entries, limit: 10)

    @paged_agenda_by_date = page_entries.group_by { |entry| entry[:time_sortable].to_date }
  end

  private

  def occurrences_for_range(range_start, range_end)
    term = params.dig(:q, :term).to_s.strip
    field = params.dig(:q, :field).presence_in(%w[name location description]) || "name"
    type = params[:type].to_s

    event_query =
      if term.present?
        case field
        when "location" then { location_cont: term }
        when "description" then { description_cont: term }
        else { title_cont: term }
        end
      else
        {}
      end


    base_events = if params[:project_id].present?
      current_user.events.where(project_id: params[:project_id])
    else
      current_user.events.where(project_id: nil)
    end

    base_events = base_events.ransack(event_query).result

    non_recurring_events = base_events.where(recurring: false)
                                      .where(starts_at: range_start..range_end)

    recurring_events = base_events.where(recurring: true)
                                  .where("starts_at <= ?", range_end)
                                  .where("repeat_until >= ?", range_start.to_date)

    events = non_recurring_events + recurring_events

    course_query =
      if term.present?
        case field
        when "location" then { location_cont: term }
        when "description" then { description_cont: term }
        else { title_cont: term }
        end
      else
        {}
      end

    courses = current_user.courses
                          .ransack(course_query)
                          .result
                          .where("start_date <= ?", range_end.to_date)
                          .where("end_date IS NULL OR end_date >= ?", range_start.to_date)

    base_work_shifts = current_user.work_shifts
                                   .where("start_date <= ?", range_end.to_date)
                                   .where("repeat_until IS NULL OR repeat_until >= ?", range_start.to_date)

    if term.present?
      base_work_shifts =
        case field
        when "location"
          base_work_shifts.where("location ILIKE :term", term: "%#{term}%")
        when "description"
          base_work_shifts.where("description ILIKE :term", term: "%#{term}%")
        else
          base_work_shifts.where("title ILIKE :term", term: "%#{term}%")
        end
    end

    event_occurrences =
      %w[course course_item work_shift].include?(type) ? [] : events.flat_map { |e| e.occurrences_between(range_start, range_end) }

    course_occurrences =
      %w[event course_item work_shift].include?(type) ? [] : courses.flat_map { |c| c.occurrences_between(range_start, range_end) }

    work_shift_occurrences =
      %w[event course course_item].include?(type) ? [] : base_work_shifts.flat_map { |ws| ws.occurrences_between(range_start, range_end) }

    course_items =
      CourseItem
        .joins(:course)
        .where(courses: { user_id: current_user.id })
        .where(due_at: range_start..range_end)
        .includes(:course)

    if term.present?
      course_items =
        case field
        when "location"
          course_items.where("courses.location ILIKE :term", term: "%#{term}%")
        when "description"
          course_items.where("course_items.details ILIKE :term", term: "%#{term}%")
        else
          course_items.where(
            "course_items.title ILIKE :term OR courses.title ILIKE :term",
            term: "%#{term}%"
          )
        end
    end

    item_occurrences = %w[event course work_shift].include?(type) ? [] : course_items.to_a

    (event_occurrences + course_occurrences + work_shift_occurrences + item_occurrences).sort_by(&:starts_at)
  end

  def agenda_entry_for(occ)
    item =
      if occ.is_a?(CourseItem)
        occ
      elsif occ.respond_to?(:item)
        occ.item
      elsif occ.respond_to?(:event)
        occ.event
      elsif occ.respond_to?(:course)
        occ.course
      end

    is_course_item = item.is_a?(CourseItem)
    is_course = item.is_a?(Course) || is_course_item
    is_work_shift = item.is_a?(WorkShift)

    href =
      if is_course_item
        course_course_item_path(item.course, item, start_date: occ.starts_at.in_time_zone.to_date)
      else
        polymorphic_path(item, start_date: occ.starts_at.in_time_zone.to_date)
      end

    type_label =
      if is_course_item
        item&.kind&.humanize.presence || "Course Item"
      elsif is_work_shift
        "Shift"
      elsif is_course
        "Course"
      else
        "Event"
      end

    {
      item: item,
      type: type_label,
      is_course_item: is_course_item,
      time: occ.starts_at.strftime("%I:%M %p"),
      time_sortable: occ.starts_at,
      title: item&.title.presence || (is_course ? "(Untitled Course)" : (is_work_shift ? "(Untitled Shift)" : "(Untitled Event)")),
      kind: is_course_item ? item&.kind&.humanize : nil,
      course_title: is_course_item ? item.course&.title : nil,
      location: is_course_item ? nil : item&.location,
      description: is_course_item ? item&.details : item&.description,
      professor: is_course_item ? nil : (is_course ? item&.professor : nil),
      color: occ.color,
      href: href
    }
  end
end
