# frozen_string_literal: true

# Adds a `convert` action that swaps the current resource for one of the
# other occurrence types (Event / Course / WorkShift). The host controller
# must define `convertible_source` returning the loaded record.
module OccurrenceConvertible
  extend ActiveSupport::Concern

  def convert
    source = convertible_source
    target_type = params[:target_type].to_s

    result = OccurrenceTypeConverter.call(source: source, target_type: target_type)

    if result.success?
      render_dashboard_refresh
    else
      Rails.logger.warn("OccurrenceTypeConverter failed: source=#{source.class}##{source.id} -> #{target_type} errors=#{result.errors.inspect}")
      respond_to do |format|
        format.turbo_stream do
          message = result.errors.first || "Could not change type."
          escaped = ERB::Util.html_escape(message)
          banner = %(<div class="p-4 text-sm text-rose-300 border-b border-rose-900 bg-rose-950/40">#{escaped}</div>).html_safe
          render turbo_stream: [
            turbo_stream.update("event_drawer", banner),
            turbo_stream.update("event_popover", banner)
          ], status: :unprocessable_entity
        end
        format.html { redirect_back fallback_location: dashboard_path, alert: result.errors.first }
      end
    end
  end

  private

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
