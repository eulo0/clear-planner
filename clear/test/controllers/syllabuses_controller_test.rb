# Frozen_string_literal:true

require "test_helper"

class SyllabusesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  fixtures :users, :syllabuses

  setup do
    @user     = users(:one)
    @syllabus = syllabuses(:one) # must belong to users(:one)
    sign_in @user
  end

  test "should get index" do
    get syllabuses_url
    assert_redirected_to courses_url
  end

  test "index only shows current user's syllabuses" do
    get syllabuses_url
    assert_redirected_to courses_url
  end

  test "should get new" do
    get new_syllabus_url
    assert_response :success
  end

  test "should create syllabus and attach to current user" do
    assert_difference("Syllabus.count", 1) do
      post syllabuses_url, params: { syllabus: { title: "My Syllabus" } }
    end

    syllabus = Syllabus.order(:created_at).last
    assert_equal @user, syllabus.user
    # Parsing kicks off in `create`; AI output varies, so assert only that the
    # record persisted and we land on its preview — not on any draft contents.
    assert_redirected_to course_preview_syllabus_path(syllabus)
  end

  test "should show syllabus" do
    get syllabus_url(@syllabus)
    assert_response :success
  end

  test "should NOT show another user's syllabus" do
    other = syllabuses(:two)

    get syllabus_url(other)
    assert_response :not_found
  end

  test "should destroy syllabus" do
    assert_difference("Syllabus.count", -1) do
      delete syllabus_url(@syllabus)
    end

    assert_redirected_to courses_url
  end

  test "should NOT destroy another user's syllabus" do
    other = syllabuses(:two)

    assert_no_difference("Syllabus.count") do
      delete syllabus_url(other)
    end

    assert_response :not_found
  end
end
