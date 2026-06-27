# frozen_string_literal: true

require "uri"

class CanvasSubscription < ApplicationRecord
  belongs_to :user

  validates :feed_url, presence: true
  validates :user_id, uniqueness: true

  STATUSES = %w[idle processing done failed].freeze
  validates :status, inclusion: { in: STATUSES }

  def masked_feed_url
    return "" if feed_url.blank?
    uri = URI.parse(feed_url) rescue nil
    return "(hidden)" unless uri&.host
    # Strip extension, then show last 4 chars of the path token so the secret
    # is hidden but the tail is recognisable (matches the task spec test).
    basename = File.basename(uri.path.to_s, ".*")
    tail = basename[-4..]
    "#{uri.scheme}://#{uri.host}/…#{tail}"
  end
end
