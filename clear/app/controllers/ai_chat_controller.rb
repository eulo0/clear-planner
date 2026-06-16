class AiChatController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!

  MAX_USER_MESSAGE_CHARS = 2_000

  def panel
    @rate = rate_limiter.usage
    render layout: false
  end

  def usage
    render json: rate_limiter.usage
  end

  def create
    user_text = params[:content].to_s.sub(/\A[ \t]+/, "").sub(/[[:space:]]+\z/, "")

    if user_text.blank?
      return respond_with_alert("Message can't be blank.")
    end

    if user_text.length > MAX_USER_MESSAGE_CHARS
      return respond_with_alert("Message is too long (max #{MAX_USER_MESSAGE_CHARS} characters). Please shorten it.")
    end

    if rate_limiter.day_exceeded?
      return respond_with_alert("Daily AI limit reached (#{Ai::RateLimiter::RPD_LIMIT} requests). Resets at midnight.")
    end

    if rate_limiter.minute_exceeded?
      return respond_with_alert("Slow down — limit is #{Ai::RateLimiter::RPM_LIMIT} requests per minute. Wait a moment and try again.")
    end

    rate_limiter.record!

    result = Ai::ChatService.call(
      user:                current_user,
      draft:               current_user_draft,
      session:             session,
      raw_message:         user_text,
      raw_history:         params[:history],
      occurrences_fetcher: method(:calendar_occurrences_for_range)
    )

    if result.error
      return respond_with_alert("AI error: #{result.error}")
    end

    respond_to do |format|
      format.turbo_stream do
        streams = [
          turbo_stream.append("ai_chat_messages",
            partial: "ai_chat/message",
            locals: { m: { "role" => "user", "content" => user_text } }
          ),
          turbo_stream.append("ai_chat_messages",
            partial: "ai_chat/message",
            locals: { m: { "role" => "assistant", "content" => result.text } }
          ),
          turbo_stream.update("ai_chat_history_wrapper",
            "<input type=\"hidden\" name=\"history\" value=\"#{ERB::Util.html_escape(result.history.to_json)}\">"),
          turbo_stream.replace("toast-container", partial: "shared/toasts"),
          turbo_stream.update("ai_chat_input", ""),
          turbo_stream.replace("ai_chat_usage", partial: "ai_chat/usage", locals: { rate: rate_limiter.usage })
        ]

        result.partials.each do |p|
          streams << turbo_stream.append("ai_chat_messages", partial: p[:name], locals: p[:locals])
        end

        if result.refresh_draft_ui
          start_date  = parse_start_date(params[:start_date])
          draft       = result.new_draft || current_user_draft
          week_start  = start_date.beginning_of_week
          range_start = week_start.beginning_of_day
          range_end   = (week_start + 6.days).end_of_day
          occurrences = calendar_occurrences_for_range(range_start, range_end, draft: draft)

          streams << turbo_stream.replace(
            "dashboard_calendar",
            partial: "dashboard/calendar_frame",
            locals: { events: occurrences, start_date: start_date, draft: draft }
          )
          streams << turbo_stream.replace(
            "draft_toggle",
            partial: "draft/toggle",
            locals: {
              start_date: start_date.iso8601,
              active_draft: draft,
              drafts: current_user_drafts.to_a,
              max_drafts: CalendarDraft::MAX_DRAFTS_PER_USER
            }
          )
          streams << turbo_stream.replace(
            "draft_banner",
            partial: "draft/banner",
            locals: { start_date: start_date.iso8601, active_draft: draft }
          )
          streams << turbo_stream.replace("agenda_list", partial: "agenda/list")
        end

        render turbo_stream: streams
      end

      format.html do
        @messages = result.history
        render :index
      end
    end
  rescue => e
    respond_with_alert("AI error: #{e.message}")
  end

  private

  def rate_limiter
    @rate_limiter ||= Ai::RateLimiter.new(current_user)
  end

  def parse_start_date(raw)
    raw.present? ? Date.parse(raw) : Date.current
  rescue ArgumentError
    Date.current
  end

  def respond_with_alert(message)
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = message
        render turbo_stream: turbo_stream.replace("toast-container", partial: "shared/toasts")
      end
      format.html { redirect_to authenticated_root_path, alert: message }
    end
  end
end
