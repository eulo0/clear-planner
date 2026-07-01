require "test_helper"

class CalendarDraftApplyTasksTest < ActiveSupport::TestCase
  test "apply! sets scheduled_at on the task from a staged update op" do
    user = users(:one)
    task = user.tasks.create!(title: "Draft essay", duration_minutes: 60)
    assert_nil task.scheduled_at

    when_at = Time.zone.parse("2026-07-02 08:00:00")
    draft = user.calendar_drafts.create!(name: "AI Plan")
    draft.add_update("task", task.id, { "scheduled_at" => when_at.iso8601 })

    draft.apply!(user)

    assert_in_delta when_at, task.reload.scheduled_at, 1.second
    assert_empty draft.reload.operations, "operations should clear after apply!"
  end
end
