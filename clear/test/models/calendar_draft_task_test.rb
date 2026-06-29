require "test_helper"

class CalendarDraftTaskTest < ActiveSupport::TestCase
  setup do
    @user  = users(:one)
    @draft = CalendarDraft.create!(user: @user, name: "Test", operations: [])
    @task  = Task.create!(title: "Study", duration_minutes: 60,
                          scheduled_at: Time.zone.parse("2026-06-29 14:00"), user: @user)
  end

  # ---------- apply! ----------

  test "apply! creates a task from a create op" do
    @draft.add_create("task", { "title" => "New Task", "duration_minutes" => 30,
                                "scheduled_at" => "2026-06-29T10:00:00Z" })
    assert_difference "Task.count", 1 do
      @draft.apply!(@user)
    end
    assert_equal "New Task", Task.last.title
  end

  test "apply! updates a task from an update op" do
    @draft.add_update("task", @task.id, { "title" => "Renamed" })
    @draft.apply!(@user)
    assert_equal "Renamed", @task.reload.title
  end

  test "apply! destroys a task from a delete op" do
    @draft.add_delete("task", @task.id)
    assert_difference "Task.count", -1 do
      @draft.apply!(@user)
    end
    assert_not Task.exists?(@task.id)
  end
end
