require "test_helper"

class CourseItemTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "ci@example.com", username: "ciuser",
                         password: "password123", confirmed_at: Time.current)
    @course = @user.courses.create!(title: "Intro", code: "FORT 101",
                                    start_time: "09:00", start_date: Date.new(2026, 1, 13),
                                    end_date: Date.new(2026, 5, 1), repeat_days: [ 1 ])
  end

  test "source enum defaults to manual and supports canvas" do
    item = @course.course_items.create!(title: "HW1", kind: :assignment)
    assert item.source_manual?
    item.update!(source: :canvas)
    assert item.source_canvas?
  end

  test "suppressing_sync_notifications skips the assignment notification" do
    assert_no_difference -> { Notification.count } do
      CourseItem.suppressing_sync_notifications do
        @course.course_items.create!(title: "Synced HW", kind: :assignment, source: :canvas)
      end
    end
  end
end
