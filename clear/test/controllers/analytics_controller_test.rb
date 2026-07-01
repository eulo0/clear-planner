# frozen_string_literal: true

require "test_helper"

class AnalyticsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
  end

  test "show renders successfully and drops removed sections" do
    get analytics_path
    assert_response :success
    # Compare tab and the donut/Week Summary cards were removed in the restyle.
    assert_no_match(/analytics_compare|This Week's Breakdown|Week Summary/, @response.body)
  end

  test "completion reflects done tasks this week" do
    week_start = Date.current.beginning_of_week
    Task.create!(user: @user, title: "A", duration_minutes: 60,
                 scheduled_at: week_start + 1.day, done: true)
    Task.create!(user: @user, title: "B", duration_minutes: 60,
                 scheduled_at: week_start + 2.days, done: false)
    get analytics_path
    assert_response :success
    assert_match(/of 2 tasks done/, @response.body)
  end

  test "up_next lists upcoming scheduled tasks" do
    Task.create!(user: @user, title: "Outline paper", duration_minutes: 90,
                 scheduled_at: Time.current + 2.hours)
    get analytics_path
    assert_response :success
    assert_match(/Outline paper/, @response.body)
  end

  test "stress peak callout surfaces the driving deadline + task" do
    course = @user.courses.create!(
      title: "Economics", code: "ECON101",
      start_date: Date.current, end_date: Date.current + 90.days,
      start_time: "09:00", end_time: "10:00", repeat_days: [ 1 ]
    )
    ci = course.course_items.create!(title: "Problem Set 9", due_at: Date.current + 1.day)
    Task.create!(user: @user, title: "PS9 work", duration_minutes: 360, course_item: ci)
    get analytics_path
    assert_response :success
    assert_match(/PS9 work/, @response.body)
    assert_match(/not planned · 6h/, @response.body)
  end
end
