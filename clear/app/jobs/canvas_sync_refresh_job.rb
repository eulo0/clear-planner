# frozen_string_literal: true

class CanvasSyncRefreshJob < ApplicationJob
  queue_as :default

  def perform(subscription_id)
    subscription = CanvasSubscription.find(subscription_id)
    subscription.update!(status: "processing", last_error: nil)

    body    = CanvasSync::FeedFetcher.call(subscription.feed_url)
    entries = CanvasSync::FeedParser.call(body)
    result  = CanvasSync::Reconciler.call(subscription, entries)

    subscription.update!(
      status: "done",
      last_synced_at: Time.current,
      last_error: nil,
      last_summary: {
        "created"           => result.created,
        "updated"           => result.updated,
        "linked"            => result.linked,
        "deleted"           => result.deleted,
        "skipped_unmatched" => result.skipped_unmatched
      }
    )
  rescue => e
    if subscription
      message = "#{e.class}: #{e.message}"
      message = message.gsub(subscription.feed_url, "[feed url]") if subscription.feed_url.present?
      subscription.update(status: "failed", last_error: message)
    end
    raise
  end
end
