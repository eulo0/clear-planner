# frozen_string_literal: true

require "test_helper"

class TasksEditDestroyTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
    @task = Task.create!(title: "Edit me", duration_minutes: 30, user: @user)
  end

  test "updates a task" do
    patch task_url(@task), params: { task: { title: "Edited", duration_minutes: 60 } }
    @task.reload
    assert_equal "Edited", @task.title
    assert_equal 60, @task.duration_minutes
  end

  test "update failure re-renders the edit form with 422" do
    patch task_url(@task), params: { task: { title: "" } }
    assert_response :unprocessable_entity
    assert_select "turbo-frame#event_drawer", 1
    assert_select "body", false, "update failure must render the bare partial, not the full app_shell layout"
    assert_select "form[action=?]", task_path(@task)
    assert_equal "Edit me", @task.reload.title
  end

  test "destroys a task" do
    assert_difference("Task.count", -1) { delete task_url(@task) }
  end

  test "GET edit renders only the drawer frame (no app_shell layout, single event_drawer)" do
    get edit_task_url(@task)
    assert_response :success
    assert_select "turbo-frame#event_drawer", 1
    assert_select "body", false, "edit must render the bare partial, not the full app_shell layout"
    assert_select "form[action=?]", task_path(@task)
    assert_select "input[name=?][value=?]", "task[title]", "Edit me"
  end

  test "GET edit for another user's task returns 404" do
    foreign = Task.create!(title: "x", duration_minutes: 10, user: users(:two))
    get edit_task_url(foreign)
    assert_response :not_found
  end

  test "cannot destroy another user's task" do
    foreign = Task.create!(title: "x", duration_minutes: 10, user: users(:two))
    delete task_url(foreign)
    assert_response :not_found
    assert Task.exists?(foreign.id)
  end

  test "cannot update another user's task" do
    foreign = Task.create!(title: "x", duration_minutes: 10, user: users(:two))
    patch task_url(foreign), params: { task: { title: "hacked" } }
    assert_response :not_found
    assert_equal "x", foreign.reload.title
  end
end
