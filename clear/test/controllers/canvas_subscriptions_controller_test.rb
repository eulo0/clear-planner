require "test_helper"

class CanvasSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "ctrl@example.com", username: "ctrluser",
                         password: "password123", confirmed_at: Time.current)
    sign_in @user
  end

  test "create connects a feed and enqueues a sync" do
    assert_enqueued_with(job: CanvasSyncRefreshJob) do
      post canvas_sync_path, params: { canvas_subscription: { feed_url: "https://canvas.test/u.ics" } }
    end
    assert_redirected_to dashboard_path
    assert @user.reload.canvas_subscription.present?
  end

  test "refresh enqueues a sync" do
    @user.create_canvas_subscription!(feed_url: "https://canvas.test/u.ics")
    assert_enqueued_with(job: CanvasSyncRefreshJob) do
      post refresh_canvas_sync_path
    end
    assert_redirected_to dashboard_path
  end

  test "update changes the feed and enqueues a sync" do
    @user.create_canvas_subscription!(feed_url: "https://canvas.test/old.ics")
    assert_enqueued_with(job: CanvasSyncRefreshJob) do
      patch canvas_sync_path, params: { canvas_subscription: { feed_url: "https://canvas.test/new.ics" } }
    end
    assert_redirected_to dashboard_path
    assert_equal "https://canvas.test/new.ics", @user.reload.canvas_subscription.feed_url
  end

  test "update with no existing subscription redirects instead of crashing" do
    patch canvas_sync_path, params: { canvas_subscription: { feed_url: "https://canvas.test/x.ics" } }
    assert_redirected_to dashboard_path
  end

  test "destroy removes the subscription but keeps items" do
    @user.create_canvas_subscription!(feed_url: "https://canvas.test/u.ics")
    delete canvas_sync_path
    assert_nil @user.reload.canvas_subscription
    assert_redirected_to dashboard_path
  end
end
