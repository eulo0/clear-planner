# frozen_string_literal: true

require "net/http"
require "uri"
require "resolv"
require "ipaddr"

module CanvasSync
  # Fetches a Canvas ICS feed over HTTP(S). Normalizes webcal:// to https://,
  # enforces scheme/size/timeout limits, blocks private/loopback targets (SSRF
  # guard), and verifies the body is an iCalendar.
  class FeedFetcher
    class Error < StandardError; end

    MAX_BYTES = 5 * 1024 * 1024
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 15

    BLOCKED_RANGES = [
      IPAddr.new("0.0.0.0/8"), IPAddr.new("127.0.0.0/8"), IPAddr.new("10.0.0.0/8"),
      IPAddr.new("172.16.0.0/12"), IPAddr.new("192.168.0.0/16"), IPAddr.new("169.254.0.0/16"),
      IPAddr.new("::1/128"), IPAddr.new("fe80::/10"), IPAddr.new("fc00::/7")
    ].freeze

    def self.call(url)
      new(url).call
    end

    def initialize(url)
      @url = url
    end

    def call
      uri = normalize(@url)
      ensure_public_host!(uri.host)
      body = fetch(uri)
      unless body.to_s.lstrip.start_with?("BEGIN:VCALENDAR")
        raise Error, "Response was not an iCalendar feed"
      end
      body
    end

    private

    def normalize(raw)
      str = raw.to_s.strip.sub(/\Awebcal:/i, "https:")
      uri = URI.parse(str)
      raise Error, "Unsupported feed URL" unless uri.is_a?(URI::HTTP)
      uri
    rescue URI::InvalidURIError
      raise Error, "Invalid feed URL"
    end

    # Basic SSRF guard: refuse feeds that resolve to private/loopback/link-local IPs.
    # Skipped in development so localhost / LAN test feeds can be used; production
    # and test still enforce it.
    def ensure_public_host!(host)
      return if Rails.env.development?

      addresses = Resolv.getaddresses(host.to_s)
      raise Error, "Could not resolve feed host" if addresses.empty?
      addresses.each do |addr|
        ip = IPAddr.new(addr)
        raise Error, "Feed host is not allowed" if BLOCKED_RANGES.any? { |range| range.include?(ip) }
      end
    rescue IPAddr::InvalidAddressError
      raise Error, "Feed host is not allowed"
    end

    def fetch(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      response = http.get(uri.request_uri)
      raise Error, "Feed returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      body = response.body.to_s
      raise Error, "Feed too large" if body.bytesize > MAX_BYTES
      body
    end
  end
end
