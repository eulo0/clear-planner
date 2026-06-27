require "test_helper"

class ProfileCanvasSyncTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "pcs@example.com", username: "pcsuser",
                         password: "password123", confirmed_at: Time.current)
    sign_in @user
  end

  test "profile shows the Canvas connect form when not connected" do
    get profile_path
    assert_response :success
    assert_includes @response.body, "LMS Sync"
    assert_includes @response.body, "Connect" # "Connect &amp; Sync" submit button
    assert_includes @response.body, "canvas_subscription[feed_url]"
  end

  test "profile shows status and masked feed when connected" do
    @user.create_canvas_subscription!(feed_url: "https://canvas.test/feeds/u_secrettoken99.ics",
                                      status: "done")
    get profile_path
    assert_response :success
    assert_includes @response.body, "Sync now"
    assert_not_includes @response.body, "secrettoken99"
  end
end
