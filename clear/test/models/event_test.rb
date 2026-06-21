require "test_helper"

class EventTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "is valid with title and starts_at" do
    event = Event.new(
      title: "Study group",
      starts_at: Time.current,
      user: users(:one)
    )

    assert event.valid?
  end

  test "requires a title" do
    event = Event.new(starts_at: Time.current, user: users(:one))
    assert_not event.valid?
  end

  test "requires starts_at" do
    event = Event.new(title: "No start time", user: users(:one))
    assert_not event.valid?
  end

  test "allows ends_at to be blank" do
    event = Event.new(
      title: "No end time",
      starts_at: Time.current,
      ends_at: nil,
      user: @user
    )

    assert event.valid?, event.errors.full_messages.to_sentence
  end

  test "ends_at must be after starts_at when present" do
    starts_at = Time.current
    event = Event.new(
      title: "Bad times",
      starts_at: starts_at,
      ends_at: starts_at - 1.hour,
      user: @user
    )

    assert_not event.valid?
    assert event.errors[:ends_at].any?
  end

  # duration fallback: derive_ends_at_from_duration

  test "sets ends_at from duration_minutes when ends_at is blank" do
    event = Event.new(
      title: "With duration",
      starts_at: Time.zone.parse("2026-06-01 09:00:00"),
      duration_minutes: 90,
      user: @user
    )

    event.valid?
    assert_equal event.starts_at + 90.minutes, event.ends_at
  end

  test "does not overwrite an explicit ends_at with duration_minutes" do
    starts_at = Time.zone.parse("2026-06-01 09:00:00")
    explicit_end = starts_at + 2.hours
    event = Event.new(
      title: "Explicit end",
      starts_at: starts_at,
      ends_at: explicit_end,
      duration_minutes: 30,
      user: @user
    )

    event.valid?
    assert_equal explicit_end, event.ends_at
  end

  test "leaves ends_at nil when duration_minutes is blank and ends_at is blank" do
    event = Event.new(
      title: "No end or duration",
      starts_at: Time.current,
      user: @user
    )

    event.valid?
    assert_nil event.ends_at
  end

  test "leaves ends_at nil when starts_at is blank" do
    event = Event.new(
      title: "No start",
      duration_minutes: 60,
      user: @user
    )

    event.valid?
    assert_nil event.ends_at
  end

  test "duration_minutes of zero sets ends_at equal to starts_at (valid via >= check)" do
    event = Event.new(
      title: "Zero duration",
      starts_at: Time.zone.parse("2026-06-01 09:00:00"),
      duration_minutes: 0,
      user: @user
    )

    event.valid?
    # 0.blank? is false, so the callback fires and sets ends_at = starts_at + 0
    # ends_at_after_starts_at uses >=, so equal times pass
    assert_equal event.starts_at, event.ends_at
    assert event.valid?
  end

  test "duration_minutes works for short durations like 15 minutes" do
    event = Event.new(
      title: "Quick meeting",
      starts_at: Time.zone.parse("2026-06-01 09:00:00"),
      duration_minutes: 15,
      user: @user
    )

    event.valid?
    assert_equal event.starts_at + 15.minutes, event.ends_at
  end

  test "duration_minutes works for long durations like 480 minutes (8 hours)" do
    event = Event.new(
      title: "All day workshop",
      starts_at: Time.zone.parse("2026-06-01 09:00:00"),
      duration_minutes: 480,
      user: @user
    )

    event.valid?
    assert_equal event.starts_at + 480.minutes, event.ends_at
  end

  # occurrences_between: a non-recurring event must only appear inside the
  # requested range, otherwise a one-off June 2026 event leaks into e.g. a 2041
  # year view (https://github.com/eulo0/clear — year-view month_count is
  # year-agnostic, which surfaces this leak).

  test "non-recurring event returns its occurrence when inside the range" do
    event = Event.create!(
      title: "One-off",
      starts_at: Time.zone.parse("2026-06-01 09:00:00"),
      ends_at: Time.zone.parse("2026-06-01 10:00:00"),
      user: @user
    )

    occs = event.occurrences_between(
      Time.zone.parse("2026-01-01 00:00:00"), Time.zone.parse("2026-12-31 23:59:59")
    )

    assert_equal 1, occs.size
    assert_equal event.starts_at, occs.first.starts_at
  end

  test "non-recurring event returns no occurrence for a range it falls outside" do
    event = Event.create!(
      title: "One-off",
      starts_at: Time.zone.parse("2026-06-01 09:00:00"),
      ends_at: Time.zone.parse("2026-06-01 10:00:00"),
      user: @user
    )

    occs = event.occurrences_between(
      Time.zone.parse("2041-01-01 00:00:00"), Time.zone.parse("2041-12-31 23:59:59")
    )

    assert_empty occs
  end
end
