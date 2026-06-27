# frozen_string_literal: true

require "icalendar"

module CanvasSync
  # Parses a Canvas ICS feed into assignment entries. Filters to assignments
  # only (structural URL signal — NOT the title, which can lie), drops events
  # with no recognizable [code], no UID, or Clear's own exported UIDs.
  class FeedParser
    class Error < StandardError; end

    Entry = Struct.new(:uid, :course_code, :title, :due_at, keyword_init: true)

    # Canvas tags assignment events with an `event-assignment-<id>` UID across
    # feed variants (real Canvas: `event-assignment-123@instructure.com`), which
    # is the most reliable signal. The URL markers are secondary fallbacks for
    # feeds that expose the assignment in the link instead.
    ASSIGNMENT_UID_RE = /\Aevent-assignment-/i
    ASSIGNMENT_URL_MARKERS = [ "/assignments/", "#assignment" ].freeze
    BRACKET_RE = /\s*\[([^\]]+)\]\s*\z/

    def self.call(ics_data)
      new(ics_data).call
    end

    def initialize(ics_data)
      @ics_data = ics_data
    end

    def call
      calendars = Icalendar::Calendar.parse(@ics_data)
      calendars.flat_map(&:events).filter_map { |vevent| build_entry(vevent) }
    rescue Icalendar::Parser::ParseError, ArgumentError => e
      Rails.logger.error("[CanvasSync::FeedParser] parse failed: #{e.class}: #{e.message}")
      raise Error, "Could not parse feed"
    end

    private

    def build_entry(vevent)
      uid = vevent.uid.to_s.presence
      return nil if uid.nil? || uid.end_with?("@clear")
      return nil unless assignment?(vevent)

      summary = vevent.summary.to_s
      code = extract_code(summary)
      return nil if code.nil?

      due_at = parse_due(vevent.dtstart)
      return nil if due_at.nil?

      Entry.new(
        uid: uid,
        course_code: code,
        title: summary.sub(BRACKET_RE, "").strip,
        due_at: due_at
      )
    end

    # Structural assignment signal (OQ1, resolved against a real feed): the
    # `event-assignment-` UID prefix is the reliable signal; URL markers are
    # fallbacks for feeds that only encode the assignment in the link.
    def assignment?(vevent)
      return true if vevent.uid.to_s.match?(ASSIGNMENT_UID_RE)

      haystack = "#{vevent.url} #{vevent.description}"
      ASSIGNMENT_URL_MARKERS.any? { |marker| haystack.include?(marker) }
    end

    def extract_code(summary)
      match = summary.match(BRACKET_RE)
      match && match[1].to_s.strip.presence
    end

    # Convert through the app zone — Canvas due dates are UTC "Z"; naive
    # parsing would land an 11:59pm-local due date on the wrong day.
    def parse_due(value)
      return nil if value.nil?
      value.to_time.in_time_zone
    end
  end
end
