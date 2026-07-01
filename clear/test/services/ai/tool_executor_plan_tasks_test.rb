require "test_helper"

module Ai
  class ToolExecutorPlanTasksTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.blocks.create!(label: "Study", start_minute: 9 * 60, end_minute: 17 * 60,
                           repeat_days: [ 1, 2, 3, 4, 5 ], status: "active")
      @course = @user.courses.create!(
        title: "CS 101", meeting_days: "MWF",
        start_time: Time.zone.parse("10:00"), end_time: Time.zone.parse("10:50"),
        start_date: Date.current, end_date: Date.current + 3.months,
        grade_calculation: "points"
      )
      @item = @course.course_items.create!(title: "Essay 1", kind: :assignment, due_at: 5.days.from_now)
      @task = @user.tasks.create!(title: "Draft essay", duration_minutes: 60, course_item: @item)
      @session = {}
      @ctx = Ai::ChatContext.new(user: @user, draft: nil, session: @session,
                                 occurrences_fetcher: ->(_s, _e, **_) { [] })
    end

    def run_plan
      Ai.with_context(@ctx) { Ai::ToolExecutor.new(@ctx).execute("plan_tasks", {}) }
    end

    test "creates an AI Plan draft, flips session to draft mode, stages task updates, renders result partial" do
      result = run_plan

      assert result[:success]
      assert_equal 1, result[:placed]
      assert @session[:calendar_draft_mode], "session should flip to draft mode"
      assert @ctx.refresh_draft_ui, "should request a draft UI refresh"
      assert_equal "ai_chat/plan_result", @ctx.partials.last&.dig(:name)

      draft = @user.calendar_drafts.find(@session[:active_calendar_draft_id])
      assert_equal "AI Plan", draft.name
      op = draft.operations.find { |o| o["type"] == "update" && o["model"] == "task" && o["id"] == @task.id }
      assert op, "expected a staged task update for the seeded task"
      assert op["data"]["scheduled_at"].present?
    end

    test "reuses the already-active draft instead of creating AI Plan" do
      existing = @user.calendar_drafts.create!(name: "Vacation")
      @ctx.draft = existing
      run_plan

      assert_equal 1, existing.reload.operations.count { |o| o["model"] == "task" }
      assert_nil @user.calendar_drafts.find_by("LOWER(name) = ?", "ai plan")
    end

    test "returns the needs_blocks partial when the user has no active blocks" do
      @user.blocks.destroy_all
      result = run_plan

      assert result[:success]
      assert_equal "ai_chat/plan_needs_blocks", @ctx.partials.last&.dig(:name)
    end

    test "reports zero placed when there are no unscheduled tasks" do
      @user.tasks.update_all(scheduled_at: Time.current)
      result = run_plan

      assert result[:success]
      assert_equal 0, result[:placed].to_i
    end

    test "returns an error when the user is at the draft cap with no AI Plan draft to reuse" do
      CalendarDraft::MAX_DRAFTS_PER_USER.times { |i| @user.calendar_drafts.create!(name: "Draft #{i}") }
      result = run_plan

      assert_not result[:success]
      assert result[:errors].join.match?(/maximum of \d+ drafts/i), result[:errors].inspect
    end
  end
end
