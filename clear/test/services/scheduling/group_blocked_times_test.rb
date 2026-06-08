require "test_helper"

module Scheduling
  class GroupBlockedTimesTest < ActiveSupport::TestCase
    setup do
      @member_a = User.create!(email: "a@example.com", username: "membera",
                               password: "password123", confirmed_at: Time.current)
      @member_b = User.create!(email: "b@example.com", username: "memberb",
                               password: "password123", confirmed_at: Time.current)

      @project = Project.create!(title: "Study Group")
      @project.project_memberships.create!(user: @member_a, role: :owner)
      @project.project_memberships.create!(user: @member_b, role: :editor)

      # A fixed Tuesday so the recurrence/exception assertions are deterministic.
      @tuesday = Date.new(2026, 6, 9)
      @range_start = @tuesday.beginning_of_week.beginning_of_day
      @range_end   = (@tuesday.beginning_of_week + 6.days).end_of_day
    end

    def intervals
      GroupBlockedTimes.new(project: @project, range_start: @range_start, range_end: @range_end).intervals
    end

    def event_for(user, starts_at, ends_at, **attrs)
      user.events.create!(title: "x", color: "#34D399", starts_at: starts_at, ends_at: ends_at, **attrs)
    end

    test "aggregates personal commitments across all members" do
      event_for(@member_a, at_hour(@tuesday, 9), at_hour(@tuesday, 10))
      event_for(@member_b, at_hour(@tuesday, 14), at_hour(@tuesday, 15))

      result = intervals
      assert_equal 2, result.size
      assert_equal [ at_hour(@tuesday, 9), at_hour(@tuesday, 14) ], result.map(&:starts_at)
    end

    test "excludes this project's own events but includes other groups' events" do
      other_group = Project.create!(title: "Other")
      other_group.project_memberships.create!(user: @member_a, role: :owner)

      event_for(@member_a, at_hour(@tuesday, 9), at_hour(@tuesday, 10), project: @project)      # excluded
      event_for(@member_a, at_hour(@tuesday, 11), at_hour(@tuesday, 12), project: other_group)  # included

      result = intervals
      assert_equal 1, result.size
      assert_equal at_hour(@tuesday, 11), result.first.starts_at
    end

    test "merges overlapping intervals from different members" do
      event_for(@member_a, at_hour(@tuesday, 9), at_hour(@tuesday, 11))
      event_for(@member_b, at_hour(@tuesday, 10), at_hour(@tuesday, 12))

      result = intervals
      assert_equal 1, result.size
      assert_equal at_hour(@tuesday, 9),  result.first.starts_at
      assert_equal at_hour(@tuesday, 12), result.first.ends_at
    end

    test "excludes all-day events" do
      event_for(@member_a, @tuesday.beginning_of_day, @tuesday.end_of_day, all_day: true)
      assert_empty intervals
    end

    test "respects recurrence exceptions" do
      event = event_for(@member_a, at_hour(@tuesday, 9), at_hour(@tuesday, 10),
                        recurring: true, repeat_days: [ @tuesday.wday ], repeat_until: @tuesday + 14.days)
      event.event_exceptions.create!(excluded_date: @tuesday)

      # Excluded on @tuesday, but the next week's Tuesday is still within range only if in window;
      # here the range is a single week, so the excluded date removes the only occurrence.
      assert_empty intervals
    end

    private

    def at_hour(date, hour)
      Time.zone.local(date.year, date.month, date.day, hour, 0, 0)
    end
  end
end
