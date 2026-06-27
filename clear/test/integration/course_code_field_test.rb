require "test_helper"

class CourseCodeFieldTest < ActionDispatch::IntegrationTest
  test "new course form renders a Course code field" do
    user = User.create!(email: "cc@example.com", username: "ccuser",
                        password: "password123", confirmed_at: Time.current)
    sign_in user
    get new_course_path
    assert_response :success
    assert_includes @response.body, "Course code"
    assert_includes @response.body, "course[code]"
  end

  test "creating a course persists the code" do
    user = User.create!(email: "cc2@example.com", username: "ccuser2",
                        password: "password123", confirmed_at: Time.current)
    sign_in user
    post courses_path, params: { course: {
      title: "Intro", code: "FORT 101", start_time: "09:00",
      start_date: "2026-01-13", end_date: "2026-12-01", repeat_days: [ 1 ]
    } }
    assert_equal "FORT 101", user.courses.last.code
  end
end
