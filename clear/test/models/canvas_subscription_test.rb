require "test_helper"

class CanvasSubscriptionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "sub@example.com", username: "subuser",
                         password: "password123", confirmed_at: Time.current)
  end

  test "requires a feed_url" do
    sub = CanvasSubscription.new(user: @user)
    assert_not sub.valid?
    assert_includes sub.errors[:feed_url], "can't be blank"
  end

  test "one subscription per user" do
    CanvasSubscription.create!(user: @user, feed_url: "https://canvas.test/u.ics")
    dup = CanvasSubscription.new(user: @user, feed_url: "https://canvas.test/v.ics")
    assert_not dup.valid?
  end

  test "masked_feed_url hides the token" do
    sub = CanvasSubscription.new(user: @user, feed_url: "https://canvas.test/feeds/u_secrettoken1234.ics")
    masked = sub.masked_feed_url
    assert_includes masked, "canvas.test"
    assert_not_includes masked, "secrettoken"
    assert masked.end_with?("1234")
  end
end
