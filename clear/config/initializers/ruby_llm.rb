RubyLLM.configure do |c|
  c.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY")
end
