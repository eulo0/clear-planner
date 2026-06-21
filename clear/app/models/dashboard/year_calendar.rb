# frozen_string_literal: true

module Dashboard
  # Aggregates a full year of calendar occurrences into the data the year-view
  # partial (app/views/dashboard/_year_calendar.html.erb) renders: a hero total,
  # one summary chip per source, and per-day dot/count/tooltip data.
  #
  # ── INTERFACE CONTRACT (frozen in Step 1; the partial and the tests both rely on it) ──
  #
  #   YearCalendar.new(year:, occurrences:, courses:, filter: nil)
  #     year        Integer calendar year, e.g. 2026.
  #     occurrences Array of the FULL year's occurrences, UNFILTERED, as returned by
  #                 calendar_occurrences_for_range(year_start, year_end, draft:) — draft
  #                 already applied. Each element is either an Occurrence struct (responds
  #                 to #event/#starts_at/#draft_status) or a CourseItem. Occurrences whose
  #                 #draft_status is "deleted" are ignored everywhere (they preview a deletion).
  #     courses     The user's courses (any order) so a course with zero items this year
  #                 still renders as a (count: 0) chip.
  #     filter      nil/"" (all) or a chip filter_value: "events", "work_shifts", a course
  #                 id string, or "courses" (all courses). Mirrors the existing `filter` param.
  #
  #   #year         -> Integer
  #   #total        -> Integer  non-removed items in the year (IGNORES filter).
  #   #chips        -> [Chip]    Events, then each course (title order), then Work Shifts.
  #                              #count is the FULL per-source count (ignores filter);
  #                              #selected is true when the chip matches the active filter.
  #   #hero_count   -> Integer  filtered ? selected chip's count : #total.
  #   #hero_label   -> String   "items planned in 2026" / "in Calculus II · 2026".
  #   #day(date)    -> Day       per-day data, RESPECTING the filter.
  #   #month_count(month_index)  -> Integer  items in month 0..11, RESPECTING the filter.
  #   #empty?       -> Boolean   #total == 0.
  #
  #   Chip = Data.define(:key, :label, :color, :count, :filter_value, :selected)
  #   Day  = Data.define(:count, :dot_colors, :items)
  #           dot_colors: up to 3 distinct source colors (source order), respecting filter.
  #           items:      [{ title:, color:, kind: }, ...] for the hover tooltip.
  Chip = Data.define(:key, :label, :color, :count, :filter_value, :selected)
  Day  = Data.define(:count, :dot_colors, :items)

  class YearCalendar
    EMPTY_DAY = Day.new(count: 0, dot_colors: [], items: []).freeze

    # Representative chip/source colors for the non-course sources. Individual
    # events/shifts keep their own record.color elsewhere, but at year zoom the
    # dots and chips read by source (matching the design), so events render
    # emerald and work shifts slate; courses use their own picked color.
    EVENTS_COLOR      = "#34D399" # app default emerald
    WORK_SHIFTS_COLOR = "#94A3B8" # neutral slate

    # Draft occurrences carrying this status preview a deletion; excluded everywhere.
    REMOVED_STATUS = "deleted"

    def initialize(year:, occurrences:, courses:, filter: nil)
      @year        = year
      @occurrences = Array(occurrences).reject { |occurrence| removed?(occurrence) }
      @courses     = courses.to_a
      @filter      = filter.presence
    end

    attr_reader :year

    def total
      @occurrences.size
    end

    def chips
      @chips ||= build_chips
    end

    def hero_count
      return total unless @filter

      selected = chips.find(&:selected)
      selected ? selected.count : 0
    end

    def hero_label
      selected = @filter && chips.find(&:selected)
      selected ? "in #{selected.label} · #{@year}" : "items planned in #{@year}"
    end

    def day(date)
      days_index.fetch(date, EMPTY_DAY)
    end

    def month_count(month_index)
      days_index.sum { |date, data| date.month == month_index + 1 ? data.count : 0 }
    end

    def empty?
      total.zero?
    end

    private

    def removed?(occurrence)
      occurrence.respond_to?(:draft_status) && occurrence.draft_status.to_s == REMOVED_STATUS
    end

    def record_for(occurrence)
      occurrence.respond_to?(:event) ? occurrence.event : occurrence
    end

    # { key:, color:, rank:, title:, kind: } describing one occurrence's source.
    # rank orders sources for the day dots: events first, courses (by title), shifts last.
    def descriptor(occurrence)
      record = record_for(occurrence)

      case record.model_name.singular
      when "event"
        { key: "events", color: EVENTS_COLOR, rank: [ 0, "" ], title: title_of(record), kind: "Event" }
      when "work_shift"
        { key: "work_shifts", color: WORK_SHIFTS_COLOR, rank: [ 2, "" ], title: title_of(record), kind: "Shift" }
      when "course"
        { key: course_key(record), color: record.color, rank: [ 1, sort_title(record) ], title: title_of(record), kind: "Class" }
      when "course_item"
        course = record.course
        { key: course_key(course), color: course.color, rank: [ 1, sort_title(course) ], title: title_of(record), kind: record.kind.to_s.humanize }
      else
        { key: "other", color: EVENTS_COLOR, rank: [ 3, "" ], title: title_of(record), kind: record.model_name.human }
      end
    end

    def course_key(course)
      "course-#{course.id}"
    end

    def sort_title(course)
      course.title.to_s.downcase
    end

    def title_of(record)
      (record.respond_to?(:title) && record.title.presence) || "(Untitled)"
    end

    def course_of(occurrence)
      record = record_for(occurrence)

      case record.model_name.singular
      when "course"      then record
      when "course_item" then record.course
      end
    end

    # Union of the user's courses and any courses found in occurrences (so every
    # course occurrence maps to a chip and chip counts sum to the total), title-ordered.
    def course_records
      @course_records ||= begin
        from_occurrences = @occurrences.filter_map { |occurrence| course_of(occurrence) }
        (@courses + from_occurrences).uniq(&:id).sort_by { |course| sort_title(course) }
      end
    end

    def source_counts
      @source_counts ||= @occurrences.each_with_object(Hash.new(0)) do |occurrence, counts|
        counts[descriptor(occurrence)[:key]] += 1
      end
    end

    def build_chips
      counts = source_counts
      list = [ chip("events", "Events", EVENTS_COLOR, counts["events"], "events") ]
      course_records.each do |course|
        key = course_key(course)
        list << chip(key, course.title, course.color, counts[key], course.id.to_s)
      end
      list << chip("work_shifts", "Work Shifts", WORK_SHIFTS_COLOR, counts["work_shifts"], "work_shifts")
      list
    end

    def chip(key, label, color, count, filter_value)
      Chip.new(key: key, label: label, color: color, count: count,
               filter_value: filter_value, selected: @filter == filter_value)
    end

    def filtered_occurrences
      return @occurrences unless @filter

      @occurrences.select { |occurrence| matches_filter?(occurrence) }
    end

    def matches_filter?(occurrence)
      key = descriptor(occurrence)[:key]

      case @filter
      when "events"      then key == "events"
      when "work_shifts" then key == "work_shifts"
      when "courses"     then key.start_with?("course-")
      else                    key == "course-#{@filter}"
      end
    end

    def days_index
      @days_index ||= filtered_occurrences
        .group_by { |occurrence| local_date(occurrence) }
        .each_with_object({}) do |(date, occurrences), index|
          index[date] = day_data(occurrences) unless date.nil?
        end
    end

    def local_date(occurrence)
      occurrence.starts_at&.in_time_zone&.to_date
    end

    def day_data(occurrences)
      descriptors = occurrences.map { |occurrence| descriptor(occurrence) }
      dot_colors  = descriptors.uniq { |d| d[:key] }.sort_by { |d| d[:rank] }.first(3).map { |d| d[:color] }
      items       = descriptors.map { |d| { title: d[:title], color: d[:color], kind: d[:kind] } }
      Day.new(count: occurrences.size, dot_colors: dot_colors, items: items)
    end
  end
end
