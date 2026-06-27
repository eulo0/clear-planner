require "test_helper"

class CanvasSyncEnqueueAllJobTest < ActiveJob::TestCase
  test "enqueues a refresh for every subscription" do
    u1 = User.create!(email: "e1@example.com", username: "e1", password: "password123", confirmed_at: Time.current)
    u2 = User.create!(email: "e2@example.com", username: "e2", password: "password123", confirmed_at: Time.current)
    s1 = CanvasSubscription.create!(user: u1, feed_url: "https://canvas.test/1.ics")
    s2 = CanvasSubscription.create!(user: u2, feed_url: "https://canvas.test/2.ics")

    assert_enqueued_jobs 2, only: CanvasSyncRefreshJob do
      CanvasSyncEnqueueAllJob.perform_now
    end
  end
end
