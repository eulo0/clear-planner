# frozen_string_literal: true

# Recurring: re-sync ALL Canvas subscriptions (no active/inactive filter).
# Scheduled in config/recurring.yml. Canvas server-side-caches feeds
# (~30-60min), so a 6-hour cadence is plenty.
# TODO: add per-feed failure backoff before re-enqueuing consistently failing subs.
class CanvasSyncEnqueueAllJob < ApplicationJob
  queue_as :default

  def perform
    CanvasSubscription.find_each do |subscription|
      CanvasSyncRefreshJob.perform_later(subscription.id)
    end
  end
end
