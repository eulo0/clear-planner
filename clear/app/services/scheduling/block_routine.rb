# frozen_string_literal: true

module Scheduling
  # Deterministically lays out availability blocks from an LLM-provided *intent*.
  # The LLM never produces times — this class does all slot math, guaranteeing
  # blocks never overlap fixed commitments or each other.
  class BlockRoutine
    DAYPARTS = {
      "morning"   => [ 8 * 60, 12 * 60 ],
      "afternoon" => [ 12 * 60, 17 * 60 ],
      "evening"   => [ 17 * 60, 21 * 60 ]
    }.freeze
    DEFAULT_DAYPARTS      = %w[morning afternoon].freeze
    WEEKDAYS              = [ 1, 2, 3, 4, 5 ].freeze   # Mon–Fri
    GRANULARITY           = 15
    DEFAULT_BLOCK_MINUTES = 120
    MIN_BLOCK_MINUTES     = 60
    MAX_PASSES            = 4

    WDAY_NAMES = { "sunday" => 0, "monday" => 1, "tuesday" => 2, "wednesday" => 3,
                   "thursday" => 4, "friday" => 5, "saturday" => 6 }.freeze

    CATEGORIES = [
      { label: "Study",     color: "#6366f1", hours_key: "study_hours_per_week" },
      { label: "Deep Work", color: "#10b981", hours_key: "deep_work_hours_per_week" },
      { label: "Errands",   color: "#f59e0b", hours_key: "errand_hours_per_week" }
    ].freeze

    Proposed = Struct.new(:label, :color, :repeat_days, :start_minute, :end_minute, keyword_init: true)

    def initialize(user:, intent:, busy_by_wday:)
      @user         = user  # reserved for future user-preference lookups
      @intent       = intent.transform_keys(&:to_s)
      @busy_by_wday = busy_by_wday.transform_keys(&:to_i)
    end

    def call
      placed_all   = []
      unplaceable  = []
      free_wdays   = WEEKDAYS - keep_free_wdays

      CATEGORIES.each do |cat|
        minutes_needed = (@intent[cat[:hours_key]].to_f * 60).round
        next if minutes_needed <= 0

        produced, remaining = place_category(cat, minutes_needed, free_wdays, placed_all)
        placed_all.concat(produced)
        unplaceable << cat[:label] if remaining > 0
      end

      { blocks: placed_all, unplaceable: unplaceable }
    end

    private

    def keep_free_wdays
      Array(@intent["keep_free"]).map { |d| WDAY_NAMES[d.to_s.downcase] }.compact
    end

    def dayparts
      requested = Array(@intent["preferred_dayparts"]).map(&:to_s).select { |d| DAYPARTS.key?(d) }
      requested.presence || DEFAULT_DAYPARTS
    end

    # One block per day per pass, cycling days so hours spread out before doubling up.
    def place_category(cat, minutes_needed, free_wdays, existing)
      produced  = []
      remaining = minutes_needed
      pass = 0
      while remaining > 0 && pass < MAX_PASSES
        progressed = false
        free_wdays.each do |wday|
          break if remaining <= 0
          occupied = occupied_minutes(wday, existing + produced)
          slot = first_free_slot(occupied, [ DEFAULT_BLOCK_MINUTES, remaining ].min)
          next unless slot
          start_m, end_m = slot
          produced << Proposed.new(label: cat[:label], color: cat[:color],
                                   repeat_days: [ wday ], start_minute: start_m, end_minute: end_m)
          remaining -= (end_m - start_m)
          progressed = true
        end
        break unless progressed
        pass += 1
      end
      [ produced, [ remaining, 0 ].max ]
    end

    def occupied_minutes(wday, blocks)
      fixed  = Array(@busy_by_wday[wday])
      placed = blocks.select { |b| b.repeat_days.first == wday }.map { |b| [ b.start_minute, b.end_minute ] }
      (fixed + placed).sort_by(&:first)
    end

    # Finds the first gap (within the preferred dayparts) big enough for `want` minutes,
    # capped at the gap size and floored at MIN_BLOCK_MINUTES.
    def first_free_slot(occupied, want)
      dayparts.each do |dp|
        win_s, win_e = DAYPARTS[dp]
        free_gaps(win_s, win_e, occupied).each do |gs, ge|
          start_m = snap(gs)
          next if start_m >= ge                 # snap consumed the whole gap
          chunk = [ ge - start_m, want ].min
          next if chunk < MIN_BLOCK_MINUTES
          return [ start_m, start_m + chunk ]      # end <= ge guaranteed
        end
      end
      nil
    end

    def free_gaps(win_s, win_e, occupied)
      gaps   = []
      cursor = win_s
      occupied.select { |os, oe| oe > win_s && os < win_e }.sort_by(&:first).each do |os, oe|
        gaps << [ cursor, os ] if os > cursor
        cursor = [ cursor, oe ].max
      end
      gaps << [ cursor, win_e ] if cursor < win_e
      gaps
    end

    def snap(minute)
      ((minute + GRANULARITY - 1) / GRANULARITY) * GRANULARITY
    end
  end
end
