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

  # ---------- build_preview_occurrences ----------

  RANGE_START = Time.zone.parse("2026-06-29 00:00").freeze
  RANGE_END   = Time.zone.parse("2026-06-29 23:59").freeze

  def base_occurrences
    @task.occurrences_between(RANGE_START, RANGE_END)
  end

  test "preview marks a deleted task as removed" do
    @draft.add_delete("task", @task.id)
    result = @draft.build_preview_occurrences(base_occurrences, RANGE_START, RANGE_END)
    assert_equal 1, result.size
    assert_equal "deleted", result.first.draft_status
  end

  test "preview shows updated scheduled_at for an updated task" do
    new_start = Time.zone.parse("2026-06-29 16:00")
    @draft.add_update("task", @task.id,
      { "scheduled_at" => new_start.iso8601, "duration_minutes" => 60 })
    result = @draft.build_preview_occurrences(base_occurrences, RANGE_START, RANGE_END)
    assert_equal 1, result.size
    assert_equal "updated", result.first.draft_status
    assert_equal new_start, result.first.starts_at
  end

  test "preview injects a draft-created scheduled task" do
    @draft.add_create("task", {
      "title" => "Draft Task", "duration_minutes" => 45,
      "scheduled_at" => "2026-06-29T10:00:00+00:00", "color" => "#34D399"
    })
    result = @draft.build_preview_occurrences([], RANGE_START, RANGE_END)
    assert_equal 1, result.size
    assert_equal "created", result.first.draft_status
    assert_equal "Draft Task", result.first.title
  end

  test "preview does not inject a draft-created task with no scheduled_at" do
    @draft.add_create("task", { "title" => "Backlog Task", "duration_minutes" => 30 })
    result = @draft.build_preview_occurrences([], RANGE_START, RANGE_END)
    assert_empty result
  end

  test "preview passes through an unaffected task occurrence unchanged" do
    result = @draft.build_preview_occurrences(base_occurrences, RANGE_START, RANGE_END)
    assert_equal 1, result.size
    assert_nil result.first.draft_status
  end
end
