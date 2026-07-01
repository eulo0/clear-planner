require "test_helper"

class Scheduling::TaskPlannerTest < ActiveSupport::TestCase
  setup do
    # Freeze to Monday 06:00 so the whole 9-17 week is in the future regardless of wall clock.
    travel_to Time.zone.local(2026, 6, 29, 6, 0)

    @user = users(:one)
    @user.events.destroy_all
    @user.courses.destroy_all
    @user.work_shifts.destroy_all
    @user.tasks.destroy_all
    @user.blocks.destroy_all
    # One wide active block every weekday, 9:00-17:00.
    @user.blocks.create!(label: "Study", start_minute: 9 * 60, end_minute: 17 * 60,
                         repeat_days: [ 1, 2, 3, 4, 5 ], status: "active")
    @range_start = Time.zone.local(2026, 6, 29, 0, 0)   # Monday
    @range_end   = Time.zone.local(2026, 7, 5, 23, 59)  # Sunday
  end

  def course_item(due_at)
    # Sunday-only meeting with no end_time → carries the deadline but adds no busy time
    # (occurrences without ends_at are skipped by the scheduler) and never overlaps the Mon-Fri block.
    course = @user.courses.create!(title: "C", start_date: @range_start.to_date,
                                   end_date: @range_end.to_date, start_time: "09:00", repeat_days: [ 0 ])
    course.course_items.create!(title: "HW", due_at: due_at, kind: :assignment)
  end

  def plan
    Scheduling::TaskPlanner.new(user: @user, range_start: @range_start, range_end: @range_end).call
  end

  test "needs_blocks :none when no active blocks" do
    @user.blocks.destroy_all
    assert_equal :none, plan[:needs_blocks]
  end

  test "needs_blocks :only_proposed when only proposed blocks exist" do
    @user.blocks.update_all(status: "proposed")
    assert_equal :only_proposed, plan[:needs_blocks]
  end

  test "places an unscheduled task inside an active block before its deadline" do
    ci = course_item(Time.zone.local(2026, 6, 30, 12, 0)) # Tue noon
    task = @user.tasks.create!(title: "Read", duration_minutes: 60, course_item: ci)

    result = plan
    a = result[:assignments].find { |x| x[:task] == task }
    assert a, "task should be placed"
    assert_operator a[:starts_at].hour, :>=, 9
    assert_operator a[:ends_at], :<=, ci.due_at
  end

  test "earliest-deadline-first ordering" do
    early = @user.tasks.create!(title: "Early", duration_minutes: 60,
                                course_item: course_item(Time.zone.local(2026, 6, 29, 11, 0)))
    late  = @user.tasks.create!(title: "Late", duration_minutes: 60,
                                course_item: course_item(Time.zone.local(2026, 7, 3, 11, 0)))
    result = plan
    early_a = result[:assignments].find { |x| x[:task] == early }
    late_a  = result[:assignments].find { |x| x[:task] == late }
    assert early_a && late_a, "both should be placed"
    assert_operator early_a[:starts_at], :<=, late_a[:starts_at]
  end

  test "no-deadline tasks are placed after deadline-bound ones" do
    dl = @user.tasks.create!(title: "Due", duration_minutes: 60,
                             course_item: course_item(Time.zone.local(2026, 6, 29, 12, 0)))
    free = @user.tasks.create!(title: "Someday", duration_minutes: 60) # no course_item
    result = plan
    dl_a   = result[:assignments].find { |x| x[:task] == dl }
    free_a = result[:assignments].find { |x| x[:task] == free }
    assert dl_a && free_a, "both should be placed"
    assert_operator dl_a[:starts_at], :<=, free_a[:starts_at]
  end

  test "does not double-book an already-scheduled task" do
    @user.tasks.create!(title: "Fixed", duration_minutes: 120,
                        scheduled_at: Time.zone.local(2026, 6, 29, 9, 0))
    t = @user.tasks.create!(title: "New", duration_minutes: 60)
    a = plan[:assignments].find { |x| x[:task] == t }
    assert a
    # Must not overlap 09:00-11:00 on Monday.
    refute (a[:starts_at] < Time.zone.local(2026, 6, 29, 11, 0) &&
            a[:ends_at]   > Time.zone.local(2026, 6, 29, 9, 0))
  end

  test "unplaceable when the task is longer than any block window" do
    ci = course_item(Time.zone.local(2026, 7, 3, 12, 0))
    t = @user.tasks.create!(title: "Marathon", duration_minutes: 10 * 60, course_item: ci) # 10h > 8h block
    result = plan
    u = result[:unplaceable].find { |x| x[:task] == t }
    assert u, "should be unplaceable"
    assert_equal :too_long, u[:reason]
  end

  test "spreads same-deadline tasks across different days instead of stacking" do
    ci = course_item(Time.zone.local(2026, 7, 3, 16, 0)) # Friday — comfortable runway
    3.times { |i| @user.tasks.create!(title: "T#{i}", duration_minutes: 60, course_item: ci) }

    result = plan
    days = result[:assignments].map { |a| a[:starts_at].to_date }.uniq
    assert_equal 3, result[:assignments].size, "all three tasks should be placed"
    assert_equal 3, days.size, "each task should land on its own day, not stack on Monday"
  end

  test "tight schedule overflows onto the same day but still meets deadlines" do
    ci = course_item(Time.zone.local(2026, 6, 29, 16, 0)) # Monday 16:00 — no runway
    6.times { |i| @user.tasks.create!(title: "T#{i}", duration_minutes: 60, course_item: ci) }

    result = plan
    assert_empty result[:unplaceable], "everything fits in Monday 9-16, nothing should drop"
    assert_equal 6, result[:assignments].size
    result[:assignments].each do |a|
      assert_operator a[:ends_at], :<=, ci.due_at, "#{a[:task].title} must end before its deadline"
    end
  end

  test "tie on due_at is deterministic by id" do
    due = Time.zone.local(2026, 7, 2, 12, 0)
    a1 = @user.tasks.create!(title: "A", duration_minutes: 60, course_item: course_item(due))
    a2 = @user.tasks.create!(title: "B", duration_minutes: 60, course_item: course_item(due))
    order = plan[:assignments].map { |x| x[:task].id }
    assert_operator order.index(a1.id), :<, order.index(a2.id)
  end
end
