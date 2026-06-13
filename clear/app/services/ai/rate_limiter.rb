module Ai
  # Per-user request rate limiting for the AI chat endpoint.
  #
  # Backed by Rails.cache (Solid Cache in production — shared across processes
  # and persistent across restarts). Replaces the old GeminiRateTracker, which
  # was a single global in-memory counter that existed only to protect Gemini's
  # shared free-tier key. Limits are now per-user and provider-agnostic.
  #
  # Uses fixed-window counters keyed by user + minute/day bucket, so each window
  # resets automatically when the clock rolls over (the daily window resets at
  # midnight in the app time zone).
  class RateLimiter
    RPM_LIMIT = ENV.fetch("AI_RPM_LIMIT", 10).to_i
    RPD_LIMIT = ENV.fetch("AI_RPD_LIMIT", 250).to_i

    def initialize(user)
      @user = user
    end

    def usage
      {
        rpm:       read(minute_key),
        rpm_limit: RPM_LIMIT,
        rpd:       read(day_key),
        rpd_limit: RPD_LIMIT
      }
    end

    # Counts one request against both the per-minute and per-day windows.
    # Returns the updated usage hash.
    def record!
      Rails.cache.increment(minute_key, 1, expires_in: 2.minutes)
      Rails.cache.increment(day_key, 1, expires_in: 25.hours)
      usage
    end

    def minute_exceeded?
      read(minute_key) >= RPM_LIMIT
    end

    def day_exceeded?
      read(day_key) >= RPD_LIMIT
    end

    private

    def read(key)
      Rails.cache.read(key).to_i
    end

    def minute_key
      "ai_rate:#{@user.id}:m:#{Time.current.strftime('%Y%m%d%H%M')}"
    end

    def day_key
      "ai_rate:#{@user.id}:d:#{Time.current.strftime('%Y%m%d')}"
    end
  end
end
