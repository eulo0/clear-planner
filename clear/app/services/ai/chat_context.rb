module Ai
  # Holds per-request state during an AI chat turn.
  # Stored in a thread-local so Tool classes can reach it without being
  # explicitly passed a reference.
  class ChatContext
    attr_reader :user, :session, :occurrences_fetcher, :partials
    attr_accessor :draft, :refresh_draft_ui

    def initialize(user:, draft:, session:, occurrences_fetcher:)
      @user                = user
      @draft               = draft
      @session             = session
      @occurrences_fetcher = occurrences_fetcher
      @partials            = []
      @refresh_draft_ui    = false
    end

    def add_partial(name, locals)
      @partials << { name: name, locals: locals }
    end
  end

  class << self
    def current_context
      Thread.current[:ai_chat_context]
    end

    def with_context(ctx)
      Thread.current[:ai_chat_context] = ctx
      yield
    ensure
      Thread.current[:ai_chat_context] = nil
    end
  end
end
