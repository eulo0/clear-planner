# frozen_string_literal: true

# Adds a `convert` action that swaps the current resource for one of the
# other occurrence types (Event / Course / WorkShift). The host controller
# must define `convertible_source` returning the loaded record.
module OccurrenceConvertible
  extend ActiveSupport::Concern

  def convert
    source = convertible_source
    target_type = params[:target_type].to_s

    # Work shifts were retired from the UI; refuse conversions that would create one,
    # independent of the (now removed) change-type dropdown option.
    if target_type == "work_shift"
      return render_convert_error("Work shifts are no longer available.")
    end

    if past_occurrence?(source, params[:start_date])
      return render_convert_error("You can't change the type of a past occurrence.")
    end

    result = OccurrenceTypeConverter.call(source: source, target_type: target_type)

    if result.success?
      render_dashboard_refresh
    else
      Rails.logger.warn("OccurrenceTypeConverter failed: source=#{source.class}##{source.id} -> #{target_type} errors=#{result.errors.inspect}")
      render_convert_error(result.errors.first || "Could not change type.")
    end
  end

  private

  def render_convert_error(message)
    flash.now[:alert] = message
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "toast-container",
          partial: "shared/toasts",
          locals: { notice: nil, alert: message }
        ), status: :unprocessable_entity
      end
      format.html { redirect_back fallback_location: dashboard_path, alert: message }
    end
  end

  def past_occurrence?(source, raw_start_date)
    occurrence_at = occurrence_datetime_for(source, raw_start_date)
    return false unless occurrence_at

    occurrence_at < Time.current
  end

  def occurrence_datetime_for(source, raw_start_date)
    date = parse_convert_start_date(raw_start_date)

    case source
    when Event
      if source.recurring? && source.starts_at.present?
        tod = source.starts_at.in_time_zone
        date.in_time_zone.change(hour: tod.hour, min: tod.min)
      else
        source.starts_at
      end
    when Course, WorkShift
      return nil unless source.start_time
      tod = source.start_time
      date.in_time_zone.change(hour: tod.hour, min: tod.min)
    end
  end

  def render_dashboard_refresh
    start_date  = parse_convert_start_date(params[:start_date])
    week_start  = start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day
    occurrences = calendar_occurrences_for_range(range_start, range_end)

    render turbo_stream: [
      turbo_stream.replace(
        "dashboard_calendar",
        partial: "dashboard/calendar_frame",
        locals: { events: occurrences, start_date: start_date, draft: nil }
      ),
      turbo_stream.replace("agenda_list", partial: "agenda/list"),
      turbo_stream.update("event_drawer", ""),
      turbo_stream.update("event_popover", "")
    ]
  end

  def parse_convert_start_date(raw)
    raw.present? ? Date.parse(raw) : Date.current
  rescue ArgumentError
    Date.current
  end
end
