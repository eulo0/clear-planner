require "test_helper"

class CanvasSyncRefreshJobTest < ActiveJob::TestCase
  # Minitest 6 removed minitest/mock. Provide a minimal .stub helper that
  # temporarily replaces a singleton method for the duration of a block,
  # matching the Minitest 5 `.stub(:method, val_or_callable) { }` API.
  module StubHelper
    def stub(method_name, val_or_callable, &block)
      original = singleton_class.instance_method(method_name)
      define_singleton_method(method_name) do |*args|
        if val_or_callable.respond_to?(:call)
          val_or_callable.call(*args)
        else
          val_or_callable
        end
      end
      block.call
    ensure
      define_singleton_method(method_name, original.bind(self))
    end
  end

  setup do
    CanvasSync::FeedFetcher.extend(StubHelper)

    @user = User.create!(email: "job@example.com", username: "jobuser",
                         password: "password123", confirmed_at: Time.current)
    @user.courses.create!(title: "Intro", code: "FORT 101", start_time: "09:00",
                          start_date: Date.new(2026, 1, 13), end_date: Date.new(2026, 12, 1),
                          repeat_days: [ 1 ])
    @sub = CanvasSubscription.create!(user: @user, feed_url: "https://canvas.test/u.ics")
  end

  def feed
    <<~ICS
      BEGIN:VCALENDAR
      VERSION:2.0
      BEGIN:VEVENT
      UID:a-1@instructure.com
      DTSTART:#{3.days.from_now.utc.strftime("%Y%m%dT%H%M%SZ")}
      SUMMARY:Essay 2 [fort101]
      URL:https://canvas.example.edu/courses/55/assignments/1
      END:VEVENT
      END:VCALENDAR
    ICS
  end

  test "fetches, reconciles, and marks done" do
    CanvasSync::FeedFetcher.stub(:call, feed) do
      CanvasSyncRefreshJob.perform_now(@sub.id)
    end
    @sub.reload
    assert_equal "done", @sub.status
    assert @sub.last_synced_at.present?
    assert_equal 1, @user.courses.first.course_items.where(canvas_uid: "a-1@instructure.com").count
  end

  test "marks failed and preserves items when the fetch errors" do
    @user.courses.first.course_items.create!(title: "Keep me", kind: :assignment,
                                             source: :canvas, canvas_uid: "keep", due_at: 5.days.from_now)
    raises = ->(_url) { raise CanvasSync::FeedFetcher::Error, "boom" }
    CanvasSync::FeedFetcher.stub(:call, raises) do
      assert_raises(CanvasSync::FeedFetcher::Error) { CanvasSyncRefreshJob.perform_now(@sub.id) }
    end
    @sub.reload
    assert_equal "failed", @sub.status
    assert_match "boom", @sub.last_error
    assert @user.courses.first.course_items.exists?(canvas_uid: "keep"), "items untouched on failure"
  end

  test "does not leak the feed url token into last_error" do
    @sub.update!(feed_url: "https://canvas.test/feeds/u_secrettoken123.ics")
    raises = ->(_url) { raise CanvasSync::FeedFetcher::Error, "failed fetching https://canvas.test/feeds/u_secrettoken123.ics" }
    CanvasSync::FeedFetcher.stub(:call, raises) do
      assert_raises(CanvasSync::FeedFetcher::Error) { CanvasSyncRefreshJob.perform_now(@sub.id) }
    end
    @sub.reload
    assert_equal "failed", @sub.status
    assert_not_includes @sub.last_error.to_s, "secrettoken123"
  end
end
