require "test_helper"

class CourseTest < ActiveSupport::TestCase
  def valid_course_attrs(overrides = {})
    {
      title: "Intro to CS",
      start_date: Date.today,
      end_date: Date.today + 16.weeks,
      start_time: Time.zone.parse("09:00"),
      meeting_days: "MWF",
      grade_calculation: "weighted",
      user: users(:one)
    }.merge(overrides)
  end

  # duration fallback: derive_end_time_from_duration

  test "sets end_time from duration_minutes when end_time is blank" do
    course = Course.new(valid_course_attrs(start_time: Time.zone.parse("09:00"), duration_minutes: 75))

    course.valid?
    # Compare against course.start_time after Rails casts the time column (base date 2000-01-01)
    assert_equal course.start_time + 75.minutes, course.end_time
  end

  test "does not overwrite an explicit end_time with duration_minutes" do
    # Use the Rails base date (2000-01-01) so times round-trip through the time column cleanly
    explicit_end = Time.zone.parse("2000-01-01 10:30:00")
    course = Course.new(valid_course_attrs(
      start_time: Time.zone.parse("09:00"),
      end_time: explicit_end,
      duration_minutes: 30
    ))

    course.valid?
    assert_equal course.end_time.hour, 10
    assert_equal course.end_time.min, 30
  end

  test "leaves end_time nil when both end_time and duration_minutes are blank" do
    course = Course.new(valid_course_attrs)

    course.valid?
    assert_nil course.end_time
  end

  test "leaves end_time nil when start_time is blank" do
    course = Course.new(valid_course_attrs(start_time: nil, duration_minutes: 60))

    course.valid?
    assert_nil course.end_time
  end

  test "duration_minutes works for a standard 50-minute class" do
    course = Course.new(valid_course_attrs(start_time: Time.zone.parse("14:00"), duration_minutes: 50))

    course.valid?
    assert_equal course.start_time + 50.minutes, course.end_time
  end

  test "duration_minutes works for a 3-hour lab (180 minutes)" do
    course = Course.new(valid_course_attrs(start_time: Time.zone.parse("13:00"), duration_minutes: 180))

    course.valid?
    assert_equal course.start_time + 180.minutes, course.end_time
  end

  test "duration_minutes of zero sets end_time equal to start_time (valid via >= check)" do
    course = Course.new(valid_course_attrs(start_time: Time.zone.parse("09:00"), duration_minutes: 0))

    course.valid?
    # 0.blank? is false, so callback fires; end_time_after_start_time uses >=, so equal times pass
    assert_equal course.start_time, course.end_time
    assert course.valid?, course.errors.full_messages.to_sentence
  end

  # basic model validity

  test "is valid with required fields and meeting_days" do
    course = Course.new(valid_course_attrs)
    assert course.valid?, course.errors.full_messages.to_sentence
  end

  test "requires a title" do
    course = Course.new(valid_course_attrs(title: nil))
    assert_not course.valid?
    assert course.errors[:title].any?
  end

  test "requires start_date" do
    course = Course.new(valid_course_attrs(start_date: nil))
    assert_not course.valid?
  end

  test "requires end_date" do
    course = Course.new(valid_course_attrs(end_date: nil))
    assert_not course.valid?
  end

  test "end_date must not be before start_date" do
    course = Course.new(valid_course_attrs(
      start_date: Date.today,
      end_date: Date.today - 1.day
    ))
    assert_not course.valid?
    assert course.errors[:end_date].any?
  end

  test "end_time must be after start_time when both present" do
    start_time = Time.zone.parse("10:00")
    course = Course.new(valid_course_attrs(
      start_time: start_time,
      end_time: start_time - 1.hour
    ))
    assert_not course.valid?
    assert course.errors[:end_time].any?
  end

  # grade_weights validation

  test "grade weights summing to 100 are valid" do
    course = Course.new(valid_course_attrs(grade_weights: { "assignment" => 60, "exam" => 40 }))
    assert course.valid?, course.errors.full_messages.to_sentence
  end

  test "grade weights exceeding 100 are invalid" do
    course = Course.new(valid_course_attrs(grade_weights: { "assignment" => 70, "exam" => 40 }))
    assert_not course.valid?
    assert course.errors[:grade_weights].any?
  end

  test "empty grade weights are valid" do
    course = Course.new(valid_course_attrs)
    assert course.valid?, course.errors.full_messages.to_sentence
  end

  # letter_grade

  test "letter_grade returns A for 90 and above" do
    course = Course.new
    assert_equal "A", course.letter_grade(90)
    assert_equal "A", course.letter_grade(100)
  end

  test "letter_grade returns B for 80 to 89.9" do
    course = Course.new
    assert_equal "B", course.letter_grade(80)
    assert_equal "B", course.letter_grade(89.9)
  end

  test "letter_grade returns C for 70 to 79.9" do
    course = Course.new
    assert_equal "C", course.letter_grade(70)
    assert_equal "C", course.letter_grade(79.9)
  end

  test "letter_grade returns D for 60 to 69.9" do
    course = Course.new
    assert_equal "D", course.letter_grade(60)
    assert_equal "D", course.letter_grade(69.9)
  end

  test "letter_grade returns F below 60" do
    course = Course.new
    assert_equal "F", course.letter_grade(59.9)
    assert_equal "F", course.letter_grade(0)
  end

  # overall_grade

  test "overall_grade returns nil when no grade weights are set" do
    course = Course.create!(valid_course_attrs)
    assert_nil course.overall_grade
  end

  test "overall_grade returns nil when no items are graded" do
    course = Course.create!(valid_course_attrs(grade_weights: { "assignment" => 100 }))
    course.course_items.create!(title: "HW 1", kind: :assignment)
    assert_nil course.overall_grade
  end

  test "overall_grade calculates correctly for a single category" do
    course = Course.create!(valid_course_attrs(grade_weights: { "assignment" => 100 }))
    course.course_items.create!(title: "HW 1", kind: :assignment, points_possible: 100, points_earned: 90)
    course.course_items.create!(title: "HW 2", kind: :assignment, points_possible: 50, points_earned: 40)
    # avg ratio = (0.9 + 0.8) / 2 = 0.85 → 85.0%
    assert_equal 85.0, course.overall_grade
  end

  test "overall_grade weights categories proportionally" do
    course = Course.create!(valid_course_attrs(grade_weights: { "assignment" => 60, "exam" => 40 }))
    course.course_items.create!(title: "HW 1", kind: :assignment, points_possible: 100, points_earned: 100)
    course.course_items.create!(title: "Exam 1", kind: :exam, points_possible: 100, points_earned: 70)
    # (60 * 1.0 + 40 * 0.7) / 100 * 100 = 88.0%
    assert_equal 88.0, course.overall_grade
  end

  test "overall_grade ignores weighted categories with no graded items" do
    course = Course.create!(valid_course_attrs(grade_weights: { "assignment" => 60, "exam" => 40 }))
    course.course_items.create!(title: "HW 1", kind: :assignment, points_possible: 100, points_earned: 80)
    # exam has a weight but no graded items — only assignment contributes
    assert_equal 80.0, course.overall_grade
  end

  test "overall_grade supports bonus points above possible" do
    course = Course.create!(valid_course_attrs(grade_weights: { "assignment" => 100 }))
    course.course_items.create!(title: "HW 1", kind: :assignment, points_possible: 100, points_earned: 110)
    assert_equal 110.0, course.overall_grade
  end

  # points mode

  test "overall_grade in points mode returns nil when no items are graded" do
    course = Course.create!(valid_course_attrs(grade_calculation: "points"))
    assert_nil course.overall_grade
  end

  test "overall_grade in points mode sums all items" do
    course = Course.create!(valid_course_attrs(grade_calculation: "points"))
    course.course_items.create!(title: "HW 1", kind: :assignment, points_possible: 100, points_earned: 90)
    course.course_items.create!(title: "HW 2", kind: :assignment, points_possible: 50, points_earned: 40)
    # (90+40) / (100+50) * 100 = 86.7%
    assert_equal 86.7, course.overall_grade
  end

  test "overall_grade in points mode spans multiple categories" do
    course = Course.create!(valid_course_attrs(grade_calculation: "points"))
    course.course_items.create!(title: "HW 1",   kind: :assignment, points_possible: 100, points_earned: 100)
    course.course_items.create!(title: "Exam 1", kind: :exam,       points_possible: 100, points_earned: 70)
    # (100+70) / (100+100) * 100 = 85.0%
    assert_equal 85.0, course.overall_grade
  end

  test "overall_grade falls back to points when weighted but weights sum to zero" do
    course = Course.create!(valid_course_attrs(grade_calculation: "weighted", grade_weights: {}))
    course.course_items.create!(title: "HW 1", kind: :assignment, points_possible: 100, points_earned: 75)
    assert_equal 75.0, course.overall_grade
  end

  # grade_calculation validation

  test "grade_calculation of points is valid" do
    course = Course.new(valid_course_attrs(grade_calculation: "points"))
    assert course.valid?, course.errors.full_messages.to_sentence
  end

  test "grade_calculation of weighted is valid" do
    course = Course.new(valid_course_attrs(grade_calculation: "weighted"))
    assert course.valid?, course.errors.full_messages.to_sentence
  end

  test "grade_calculation of unknown value is invalid" do
    course = Course.new(valid_course_attrs(grade_calculation: "magic"))
    assert_not course.valid?
    assert course.errors[:grade_calculation].any?
  end
end
