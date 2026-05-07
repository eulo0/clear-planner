class GeminiClient
  require "net/http"
  require "json"
  require "uri"

  BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"
  DEFAULT_MODEL = "gemini-2.5-flash"

  MAX_RETRIES = 3
  BASE_BACKOFF = 2 # seconds

  GENERATION_CONFIG = {
    maxOutputTokens: 8192,
    temperature: 0.4
  }.freeze

  class RateLimitExhausted < StandardError; end

  def self.api_key
    ENV.fetch("GEMINI_API_KEY")
  end

  def self.model
    ENV.fetch("GEMINI_MODEL", DEFAULT_MODEL)
  end

  # Returns a hash: { text: "...", function_calls: [{ name:, args: }, ...] }
  # Both keys are always present; function_calls is [] when the model returned only text.
  def self.chat(messages:, system_instruction: nil, tools: nil)
    contents = build_contents(messages)

    payload = { contents: contents, generationConfig: GENERATION_CONFIG }
    payload[:systemInstruction] = { parts: [ { text: system_instruction } ] } if system_instruction.present?
    payload[:tools] = tools if tools.present?

    body = send_request_with_retry(payload)

    candidate_parts = body.dig("candidates", 0, "content", "parts") || []

    function_calls = candidate_parts.filter_map do |p|
      next unless p["functionCall"]
      { name: p.dig("functionCall", "name"), args: p.dig("functionCall", "args") || {} }
    end
    text = candidate_parts.filter_map { |p| p["text"] }.join

    { text: text, function_calls: function_calls }
  end

  def self.build_contents(messages)
    messages.map do |m|
      role = (m[:role] || m["role"]).to_s
      role = "model" if role == "assistant"

      parts = m[:parts] || m["parts"]
      unless parts
        text = (m[:content] || m["content"]).to_s
        parts = [ { text: text } ]
      end

      { role: role, parts: parts }
    end
  end

  def self.send_request_with_retry(payload)
    retries = 0

    loop do
      uri = URI("#{BASE_URL}/#{model}:generateContent?key=#{api_key}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = payload.to_json

      response = http.request(request)
      body = JSON.parse(response.body)

      if response.code.to_i == 429
        retries += 1
        if retries > MAX_RETRIES
          raise RateLimitExhausted, "I'm a little busy right now, please try again in a moment."
        end

        wait_time = parse_retry_delay(body) || (BASE_BACKOFF**retries)
        Rails.logger.info "[GeminiClient] Rate limited. Retry #{retries}/#{MAX_RETRIES}, waiting #{wait_time}s"
        sleep(wait_time)
        next
      end

      if response.code.to_i != 200
        error_msg = body.dig("error", "message") || "Unknown Gemini API error"
        raise "Gemini API error (#{response.code}): #{error_msg}"
      end

      return body
    end
  end

  # Try to parse "Please retry in 19.171983245s" from the error body
  def self.parse_retry_delay(body)
    message = body.dig("error", "message").to_s
    match = message.match(/retry in (\d+\.?\d*)s/i)
    return nil unless match
    match[1].to_f.ceil # round up to be safe
  end

  private_class_method :build_contents, :send_request_with_retry, :parse_retry_delay
end
