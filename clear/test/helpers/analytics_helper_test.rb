# frozen_string_literal: true

require "test_helper"

class AnalyticsHelperTest < ActionView::TestCase
  test "format_duration_short" do
    assert_equal "6h 30m", format_duration_short(390)
    assert_equal "2h", format_duration_short(120)
    assert_equal "45m", format_duration_short(45)
    assert_equal "0m", format_duration_short(0)
  end

  test "relative_day_label" do
    today = Date.new(2026, 6, 30)
    assert_equal "today", relative_day_label(Date.new(2026, 6, 30), today)
    assert_equal "tomorrow", relative_day_label(Date.new(2026, 7, 1), today)
    assert_equal "in 3 days", relative_day_label(Date.new(2026, 7, 3), today)
  end

  test "stress level and color thresholds" do
    assert_equal :calm, stress_level(49)
    assert_equal :moderate, stress_level(50)
    assert_equal :heavy, stress_level(75)
    assert_equal "#ef4444", stress_color(90)
    assert_equal "#10b981", stress_color(10)
  end

  test "stress_smooth_path builds a bezier path" do
    path = stress_smooth_path([ [ 0, 0 ], [ 10, 5 ], [ 20, 0 ] ])
    assert path.start_with?("M 0 0")
    assert_includes path, "C"
    assert path.end_with?("20 0")
    assert_equal "", stress_smooth_path([ [ 0, 0 ] ])
  end
end
