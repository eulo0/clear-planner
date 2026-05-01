# frozen_string_literal: true

class CalendarExportService
  WDAY_TO_ICAL = { 0 => "SU", 1 => "MO", 2 => "TU", 3 => "WE", 4 => "TH", 5 => "FR", 6 => "SA" }.freeze

  def initialize(user)
    @user = user
  end

  def generate
    cal = +"BEGIN:VCALENDAR\r\n"
    cal << "VERSION:2.0\r\n"
    cal << "PRODID:-//Clear//Clear Calendar//EN\r\n"
    cal << "CALSCALE:GREGORIAN\r\n"
    cal << "METHOD:PUBLISH\r\n"
    cal << "X-WR-CALNAME:Clear Calendar\r\n"

    @user.events.includes(:event_exceptions).each do |event|
      cal << vevent_for_event(event)
    end

    @user.courses.includes(:course_items).each do |course|
      cal << vevent_for_course(course)
      course.course_items.each { |item| cal << vevent_for_course_item(item, course) }
    end

    @user.work_shifts.each { |shift| cal << vevent_for_work_shift(shift) }

    cal << "END:VCALENDAR\r\n"
    cal
  end

  private

  def vevent_for_event(event)
    lines = []
    lines << "BEGIN:VEVENT"
    lines << "UID:event-#{event.id}@clear"
    lines << "DTSTAMP:#{format_datetime(Time.current)}"
    lines << "SUMMARY:#{escape_text(event.title)}"
    lines << "DESCRIPTION:#{escape_text(event.description)}" if event.description.present?
    lines << "LOCATION:#{escape_text(event.location)}" if event.location.present?

    if event.all_day?
      lines << "DTSTART;VALUE=DATE:#{event.starts_at.to_date.strftime('%Y%m%d')}"
      lines << "DTEND;VALUE=DATE:#{(event.starts_at.to_date + 1).strftime('%Y%m%d')}"
    else
      lines << "DTSTART:#{format_datetime(event.starts_at)}"
      lines << "DTEND:#{format_datetime(event.ends_at)}" if event.ends_at.present?
    end

    if event.recurring?
      byday = Array(event.repeat_days).map { |d| WDAY_TO_ICAL[d.to_i] }.compact.join(",")
      until_part = event.repeat_until.present? ? ";UNTIL=#{event.repeat_until.strftime('%Y%m%d')}T235959Z" : ""
      lines << "RRULE:FREQ=WEEKLY;BYDAY=#{byday}#{until_part}"

      event.event_exceptions.each do |ex|
        lines << "EXDATE;VALUE=DATE:#{ex.excluded_date.strftime('%Y%m%d')}"
      end
    end

    lines << "END:VEVENT"
    format_vevent(lines)
  end

  def vevent_for_course(course)
    first_day = find_first_occurrence(course.start_date, Array(course.repeat_days).map(&:to_i))
    return "" unless first_day

    start_dt = Time.zone.local(first_day.year, first_day.month, first_day.day,
                               course.start_time.hour, course.start_time.min, 0)
    end_dt = course.end_time.present? ?
      Time.zone.local(first_day.year, first_day.month, first_day.day,
                      course.end_time.hour, course.end_time.min, 0) : nil

    description_parts = [ course.code, course.professor, course.description ].select(&:present?)

    lines = []
    lines << "BEGIN:VEVENT"
    lines << "UID:course-#{course.id}@clear"
    lines << "DTSTAMP:#{format_datetime(Time.current)}"
    lines << "SUMMARY:#{escape_text(course.title)}"
    lines << "DESCRIPTION:#{escape_text(description_parts.join(' | '))}" if description_parts.any?
    lines << "LOCATION:#{escape_text(course.location)}" if course.location.present?
    lines << "DTSTART:#{format_datetime(start_dt)}"
    lines << "DTEND:#{format_datetime(end_dt)}" if end_dt.present?

    byday = Array(course.repeat_days).map { |d| WDAY_TO_ICAL[d.to_i] }.compact.join(",")
    lines << "RRULE:FREQ=WEEKLY;BYDAY=#{byday};UNTIL=#{course.end_date.strftime('%Y%m%d')}T235959Z"

    lines << "END:VEVENT"
    format_vevent(lines)
  end

  def vevent_for_course_item(item, course)
    return "" unless item.due_at.present?

    lines = []
    lines << "BEGIN:VEVENT"
    lines << "UID:course-item-#{item.id}@clear"
    lines << "DTSTAMP:#{format_datetime(Time.current)}"
    lines << "SUMMARY:#{escape_text("#{course.title} — #{item.kind.capitalize}: #{item.title}")}"
    lines << "DESCRIPTION:#{escape_text(item.details)}" if item.details.present?
    lines << "DTSTART:#{format_datetime(item.due_at)}"
    lines << "DTEND:#{format_datetime(item.due_at + 30.minutes)}"
    lines << "END:VEVENT"
    format_vevent(lines)
  end

  def vevent_for_work_shift(shift)
    first_day = if shift.recurring?
      find_first_occurrence(shift.start_date, Array(shift.repeat_days).map(&:to_i))
    else
      shift.start_date
    end
    return "" unless first_day

    start_dt = Time.zone.local(first_day.year, first_day.month, first_day.day,
                               shift.start_time.hour, shift.start_time.min, 0)
    end_dt = Time.zone.local(first_day.year, first_day.month, first_day.day,
                             shift.end_time.hour, shift.end_time.min, 0)

    lines = []
    lines << "BEGIN:VEVENT"
    lines << "UID:shift-#{shift.id}@clear"
    lines << "DTSTAMP:#{format_datetime(Time.current)}"
    lines << "SUMMARY:#{escape_text(shift.title)}"
    lines << "DESCRIPTION:#{escape_text(shift.description)}" if shift.description.present?
    lines << "LOCATION:#{escape_text(shift.location)}" if shift.location.present?
    lines << "DTSTART:#{format_datetime(start_dt)}"
    lines << "DTEND:#{format_datetime(end_dt)}"

    if shift.recurring?
      days_ints = Array(shift.repeat_days).map(&:to_i)
      byday = days_ints.map { |d| WDAY_TO_ICAL[d] }.compact.join(",")
      until_part = shift.repeat_until.present? ? ";UNTIL=#{shift.repeat_until.strftime('%Y%m%d')}T235959Z" : ""
      lines << "RRULE:FREQ=WEEKLY;BYDAY=#{byday}#{until_part}"
    end

    lines << "END:VEVENT"
    format_vevent(lines)
  end

  def find_first_occurrence(start_date, repeat_days_wday)
    d = start_date
    7.times do
      return d if repeat_days_wday.include?(d.wday)
      d += 1.day
    end
    nil
  end

  def format_datetime(dt)
    dt.utc.strftime("%Y%m%dT%H%M%SZ")
  end

  def escape_text(text)
    return "" if text.blank?
    text.to_s.gsub("\\", "\\\\\\\\").gsub("\n", "\\n").gsub(",", "\\,").gsub(";", "\\;")
  end

  # Fold long lines per RFC 5545 (max 75 octets per line, continuation with space)
  def fold_line(line)
    return [ line ] if line.bytesize <= 75

    result = []
    while line.bytesize > 75
      chunk = line.byteslice(0, 75)
      result << chunk
      line = " " + line.byteslice(75, line.bytesize)
    end
    result << line
    result
  end

  def format_vevent(lines)
    folded = lines.flat_map { |l| fold_line(l) }
    folded.join("\r\n") + "\r\n"
  end
end
