# frozen_string_literal: true

require "icalendar"

module CalendarImports
  class IcsParser
    # Maps iCal weekday codes to Ruby's wday (0 = Sunday).
    WDAY_FROM_ICAL = { "SU" => 0, "MO" => 1, "TU" => 2, "WE" => 3, "TH" => 4, "FR" => 5, "SA" => 6 }.freeze

    def self.call(ics_data)
      new(ics_data).call
    end

    def initialize(ics_data)
      @ics_data = ics_data
    end

    # Returns an array of Event attribute hashes ready for create!.
    def call
      calendars = Icalendar::Calendar.parse(@ics_data)
      calendars.flat_map(&:events).map { |vevent| build_attrs(vevent) }.compact
    end

    private

    def build_attrs(vevent)
      # Parse DTSTART; skip events that don't have one.
      starts_at, all_day = parse_dt(vevent.dtstart)
      return nil unless starts_at

      # Parse DTEND, then fix iCal's exclusive end for all-day events.
      ends_at, _ = parse_dt(vevent.dtend)
      ends_at = adjust_all_day_end(starts_at, ends_at) if all_day

      attrs = {
        title:       vevent.summary.to_s.presence || "Untitled event",
        description: vevent.description.to_s.presence,
        location:    vevent.location.to_s.presence,
        starts_at:   starts_at,
        ends_at:     ends_at,
        all_day:     all_day,
        recurring:   false,
        repeat_days: [],
        repeat_until: nil
      }

      apply_recurrence(attrs, vevent)
      attrs
    end

    # iCal DTEND is exclusive for all-day events, so subtract one day.
    def adjust_all_day_end(starts_at, ends_at)
      return nil if ends_at.nil?
      end_date = ends_at.to_date - 1
      return nil if end_date <= starts_at.to_date
      Time.zone.local(end_date.year, end_date.month, end_date.day)
    end

    # Returns [Time, all_day?]. Date-only values become midnight in the local zone.
    def parse_dt(value)
      return [ nil, false ] if value.nil?

      if value.is_a?(Icalendar::Values::Date) || (value.respond_to?(:ical_params) && value.ical_params["VALUE"]&.include?("DATE"))
        date = value.to_date
        [ Time.zone.local(date.year, date.month, date.day), true ]
      else
        [ value.to_time.in_time_zone, false ]
      end
    end

    # Reads RRULE and copies weekly recurrence into attrs.
    # Non-weekly RRULEs are dropped so the event imports as one-time.
    def apply_recurrence(attrs, vevent)
      rrule = Array(vevent.rrule).first
      return unless rrule

      # Split "FREQ=WEEKLY;BYDAY=MO;UNTIL=..." into a hash.
      rrule_str = rrule.respond_to?(:value_ical) ? rrule.value_ical : rrule.to_s
      parts = rrule_str.to_s.split(";").map { |p| p.split("=", 2) }.to_h

      return unless parts["FREQ"] == "WEEKLY"

      # Convert BYDAY codes to wday integers; fall back to DTSTART's weekday.
      byday = parts["BYDAY"].to_s.split(",").map { |d| WDAY_FROM_ICAL[d.strip[-2..]] }.compact
      byday = [ attrs[:starts_at].wday ] if byday.empty?

      # CLEAR requires repeat_until, so skip open-ended recurrences.
      repeat_until = parse_until(parts["UNTIL"])
      return unless repeat_until

      attrs[:recurring]    = true
      attrs[:repeat_days]  = byday
      attrs[:repeat_until] = repeat_until
    end

    # UNTIL is a date or a UTC datetime. Datetimes convert to local zone so boundaries near midnight don't roll into the next day.
    def parse_until(value)
      return nil if value.blank?
      if value.include?("T")
        Time.parse(value).in_time_zone.to_date rescue nil
      else
        Date.parse(value) rescue nil
      end
    end
  end
end
