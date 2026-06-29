module Ai
  class ChatService
    MODEL          = ENV.fetch("LLM_MODEL", "claude-haiku-4-5-20251001")
    HISTORY_LIMIT  = 20

    ALL_TOOLS = [
      Ai::Tools::SelectDraft,
      Ai::Tools::CreateEvent,
      Ai::Tools::EditEvent,
      Ai::Tools::DeleteEvent,
      Ai::Tools::CreateWorkShift,
      Ai::Tools::EditWorkShift,
      Ai::Tools::DeleteWorkShift,
      Ai::Tools::ShowSchedule,
      Ai::Tools::ShowCreateForm,
      Ai::Tools::ShowDraftPicker,
      Ai::Tools::ProposeRoutine
    ].freeze

    Result = Data.define(:text, :history, :refresh_draft_ui, :partials, :new_draft, :error)

    def self.call(user:, draft:, session:, raw_message:, raw_history:, occurrences_fetcher:)
      new(user: user, draft: draft, session: session,
          raw_message: raw_message, raw_history: raw_history,
          occurrences_fetcher: occurrences_fetcher).call
    end

    def initialize(user:, draft:, session:, raw_message:, raw_history:, occurrences_fetcher:)
      @user               = user
      @draft              = draft
      @session            = session
      @raw_message        = raw_message
      @raw_history        = raw_history
      @occurrences_fetcher = occurrences_fetcher
    end

    def call
      ctx = Ai::ChatContext.new(
        user:                @user,
        draft:               @draft,
        session:             @session,
        occurrences_fetcher: @occurrences_fetcher
      )

      drafts = @user.calendar_drafts.recent.to_a
      system = Ai::SystemPrompt.build(user: @user, draft: @draft, drafts: drafts)

      history = parse_history(@raw_history)
      history << { "role" => "user", "content" => @raw_message }

      response_text = Ai.with_context(ctx) do
        chat = RubyLLM.chat(model: MODEL)
        chat.with_instructions(system)

        trimmed = trim_history(history.first(history.length - 1))
        trimmed.each { |m| chat.add_message(role: m["role"].to_sym, content: m["content"]) }

        response = chat.with_tools(*ALL_TOOLS).ask(@raw_message)
        response.content.to_s
      end

      history << { "role" => "assistant", "content" => response_text }

      Result.new(
        text:             response_text,
        history:          history,
        refresh_draft_ui: ctx.refresh_draft_ui,
        partials:         ctx.partials,
        new_draft:        ctx.draft != @draft ? ctx.draft : nil,
        error:            nil
      )
    rescue RubyLLM::Error => e
      Result.new(text: nil, history: parse_history(@raw_history), refresh_draft_ui: false,
                 partials: [], new_draft: nil, error: e.message)
    end

    private

    def parse_history(raw)
      return [] if raw.blank?
      arr = JSON.parse(raw.to_s)
      return [] unless arr.is_a?(Array)
      arr.select { |m| m.is_a?(Hash) && m["role"].present? && m["content"].present? }.last(50)
    rescue JSON::ParserError
      []
    end

    def trim_history(history)
      return history if history.length <= HISTORY_LIMIT

      [
        { "role" => "user",      "content" => "Previous conversation context has been trimmed for efficiency." },
        { "role" => "assistant", "content" => "Understood, I'll continue from the recent messages." }
      ] + history.last(HISTORY_LIMIT)
    end
  end
end
