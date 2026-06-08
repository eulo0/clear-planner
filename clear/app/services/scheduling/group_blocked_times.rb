module Scheduling
  # Aggregates the busy times of every member of a project (group) into a set of
  # anonymous, merged time intervals — used to render "blocked time" blocks on the
  # group dashboard so the group can find a shared time without exposing what each
  # member is actually doing.
  #
  # Only bare start/end times ever leave this service; titles, members, and counts
  # are intentionally dropped so private detail cannot reach the view.
  class GroupBlockedTimes
    Interval = Struct.new(:starts_at, :ends_at, keyword_init: true)

    def initialize(project:, range_start:, range_end:)
      @project = project
      @range_start = range_start
      @range_end = range_end
    end

    # Sorted, non-overlapping array of Interval covering the given range.
    def intervals
      merge(collect)
    end

    private

    def collect
      out = []
      @project.users.each do |user|
        # Personal events + events in the member's OTHER groups; this project's own
        # events are excluded because they already render as real events.
        user.events
            .where("project_id IS NULL OR project_id != ?", @project.id)
            .where("starts_at <= ?", @range_end)
            .where("recurring = FALSE OR repeat_until >= ?", @range_start.to_date)
            .reject(&:all_day?)
            .each { |event| push(out, event) }

        user.courses.each { |course| push(out, course) }
        user.work_shifts.active.each { |shift| push(out, shift) }
      end
      out
    end

    def push(out, record)
      record.occurrences_between(@range_start, @range_end).each do |occ|
        out << [ occ.starts_at, occ.ends_at ] if occ.starts_at && occ.ends_at
      end
    end

    def merge(pairs)
      pairs.sort_by(&:first).each_with_object([]) do |(starts_at, ends_at), acc|
        if acc.any? && starts_at <= acc.last[1]
          acc.last[1] = ends_at if ends_at > acc.last[1]
        else
          acc << [ starts_at, ends_at ]
        end
      end.map { |starts_at, ends_at| Interval.new(starts_at: starts_at, ends_at: ends_at) }
    end
  end
end
