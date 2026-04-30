# frozen_string_literal: true

require "stringio"
require "pdf/reader"
require "date"

module UniversityCalendar
  class PdfParser
    MONTH_NAMES = {
      "january" => 1, "february" => 2, "march" => 3, "april" => 4,
      "may" => 5, "june" => 6, "july" => 7, "august" => 8,
      "september" => 9, "october" => 10, "november" => 11, "december" => 12,
      "jan" => 1, "feb" => 2, "mar" => 3, "apr" => 4,
      "jun" => 6, "jul" => 7, "aug" => 8,
      "sep" => 9, "sept" => 9, "oct" => 10, "nov" => 11, "dec" => 12
    }.freeze

    MONTH_RE = /(?:January|February|March|April|May|June|July|August|September|October|November|December)\.?/i

    WEEKDAY_RE = /(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)/i
    WEEKDAY_RANGE_RE = /#{WEEKDAY_RE}\s*(?:-\s*#{WEEKDAY_RE})?/

    # Tabular row: Month  Day(s)  Weekday(s)  Description
    TABLE_ROW = /\A\s*(?<month_part>(?:#{MONTH_RE})(?:\s*[-\/]\s*#{MONTH_RE})?)\s+(?<day_part>\d{1,2}(?:\s*-\s*\d{1,2})?)\s+(?<weekday_part>#{WEEKDAY_RANGE_RE})\s+(?<description>.+)/i

    # Semester headers like "FALL SEMESTER 2025", "SPRING SEMESTER 2026", "SUMMER I 2026"
    SEMESTER_HEADER = /\A\s*(?:FALL|SPRING|WINTER|SUMMER\s*(?:I{1,2})?)\s+(?:SEMESTER\s+)?(\d{4})\b/i
    WINTERSESSION_HEADER = /\A\s*WINTERSESSION\b.*?(\d{4})\s*-\s*\w+\s+(\d{4})/i

    SKIP_LINE = /\A\s*(?:20\d{2}\s*-\s*20\d{2}\s+ACADEMIC|Last updated|Approved:|Please note:|page\s+\d+|table\s+of\s+contents)\b/i

    def self.call(pdf_data)
      reader = PDF::Reader.new(StringIO.new(pdf_data))
      text = reader.pages.map(&:text).join("\n")
      new(text).parse
    end

    def initialize(text)
      @text = text
    end

    def parse
      lines = normalize_lines(@text)
      items = []
      current_year = nil

      # First pass: join continuation lines onto their parent row
      merged = merge_continuation_lines(lines)

      merged.each do |line|
        next if line.match?(SKIP_LINE)
        next if line.strip.length < 5

        # Track semester year from headers
        if (m = line.match(SEMESTER_HEADER))
          current_year = m[1].to_i
          @semester_end_year = nil
          next
        end
        if (m = line.match(WINTERSESSION_HEADER))
          current_year = m[1].to_i
          @semester_end_year = m[2].to_i
          next
        end

        year = current_year || extract_fallback_year(line)
        result = extract_event(line, year)
        items << result if result
      end

      # Only keep events from today onward
      today = Date.today
      items.reject! { |item| item[:starts_at].to_date < today }

      deduplicate(items)
    end

    private

    # Joins wrapped description lines back onto their date rows
    def merge_continuation_lines(lines)
      merged = []
      pending = []

      lines.each do |line|
        stripped = line.strip
        next if stripped.empty?

        is_row = stripped.match?(/\A(?:#{MONTH_RE})/i)
        is_header = stripped.match?(SEMESTER_HEADER) || stripped.match?(WINTERSESSION_HEADER)
        is_skip = stripped.match?(SKIP_LINE)

        if is_header
          flush_pending_to_previous(merged, pending)
          pending = []
          merged << stripped
        elsif is_row
          stripped = apply_pending(merged, pending, stripped)
          pending = []
          merged << stripped
        elsif !is_skip
          # Non-row, non-skip line — hold it until we know which row it belongs to
          pending << stripped
        end
      end

      flush_pending_to_previous(merged, pending)

      merged
    end

    # Fragment continuations go to the previous row; phrase continuations go to this row
    def apply_pending(merged, pending, stripped)
      return stripped if pending.empty?

      # Split pending at the first non-fragment line
      frag_end = 0
      frag_end += 1 while frag_end < pending.size && fragment?(pending[frag_end])
      fragment_part = pending[0...frag_end]
      phrase_part = pending[frag_end..] || []

      # Fragments are wraps of the previous row
      if fragment_part.any? && merged.any?
        merged[-1] = [ merged[-1], *fragment_part ].join(" ")
      end

      # Phrase lines are the start of this row's description
      if phrase_part.any?
        row_match = stripped.match(TABLE_ROW)
        if row_match
          existing = row_match[:description].strip
          new_desc = [ *phrase_part, existing ].join(" ")
          stripped = stripped.sub(existing, new_desc)
        else
          # Row had no inline description
          stripped = "#{stripped} #{phrase_part.join(' ')}"
        end
      end

      stripped
    end

    def flush_pending_to_previous(merged, pending)
      return if pending.empty? || merged.empty?
      merged[-1] = [ merged[-1], *pending ].join(" ")
    end

    def fragment?(desc)
      # A fragment typically starts with lowercase, a quote/paren, or common continuation words
      desc.match?(/\A["""\u201C\u201D\(a-z\\]/) ||
        desc.match?(/\A(?:is issued|changes at|grade is|p\.m|a\.m|ends at|\d{4}\)|issued)/i)
    end

    def clean_description(desc)
      desc = desc.sub(/\s*Approved:.*\z/i, "")
      desc = desc.sub(/\s*Please note:.*\z/i, "")
      desc = desc.strip

      return nil if fragment?(desc)

      desc.presence
    end

    def extract_event(line, year)
      m = line.match(TABLE_ROW)
      return nil unless m

      month_part = m[:month_part]
      day_part   = m[:day_part]
      description = clean_description(m[:description])

      return nil if description.blank?

      # Parse start/end months
      months = month_part.scan(/#{MONTH_RE}/i).map { |mo| resolve_month(mo) }
      start_month = months.first
      return nil unless start_month

      # Parse start/end days
      days = day_part.scan(/\d+/).map(&:to_i)
      start_day = days.first
      end_day   = days.last if days.size > 1

      year ||= infer_year(start_month)
      # For cross-year semesters (Wintersession), use end year for Jan-Jul months
      if @semester_end_year && start_month.between?(1, 7)
        year = @semester_end_year
      end
      starts_at = safe_date(year, start_month, start_day)
      return nil unless starts_at

      ends_at = nil
      if end_day
        end_month = months.size > 1 ? months.last : start_month
        end_year = year
        # Handle cross-year ranges (e.g. December 19 - January 2)
        end_year += 1 if end_month < start_month
        ends_at = safe_date(end_year, end_month, end_day)
      end

      { title: description, starts_at: starts_at.to_time, ends_at: ends_at&.to_time, all_day: true }
    end

    def resolve_month(str)
      MONTH_NAMES[str.to_s.downcase.delete(".").strip]
    end

    def safe_date(year, month, day)
      Date.new(year, month, day)
    rescue ArgumentError
      nil
    end

    def extract_fallback_year(line)
      m = @text.match(/\b(20\d{2})\b/)
      m ? m[1].to_i : Date.today.year
    end

    def infer_year(month)
      today = Date.today
      today.month >= 8 && month.between?(1, 7) ? today.year + 1 : today.year
    end

    def normalize_lines(text)
      text.gsub("\u00A0", " ")
          .tr("\u2013\u2014\u2212", "-")
          .lines
          .map { |l| l.rstrip.gsub(/\s+/, " ") }
    end

    def deduplicate(items)
      seen = Set.new
      items.select do |item|
        key = "#{item[:title].downcase.strip}|#{item[:starts_at]&.to_date}"
        seen.add?(key)
      end
    end
  end
end
