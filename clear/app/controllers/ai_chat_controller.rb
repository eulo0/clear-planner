class AiChatController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!

  def panel
    @rate = GeminiRateTracker.usage
    render layout: false
  end

  def usage
    render json: GeminiRateTracker.usage
  end

  def create
    user_text = params[:content].to_s
                               .sub(/\A[ \t]+/, "")
                               .sub(/[[:space:]]+\z/, "")
    history   = parse_history(params[:history])

    if user_text.blank?
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Message can't be blank."
          render turbo_stream: turbo_stream.replace("toast-container", partial: "shared/toasts")
        end
        format.html { redirect_to authenticated_root_path, alert: "Message can't be blank." }
      end
      return
    end

    if user_text.length > MAX_USER_MESSAGE_CHARS
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Message is too long (max #{MAX_USER_MESSAGE_CHARS} characters). Please shorten it."
          render turbo_stream: turbo_stream.replace("toast-container", partial: "shared/toasts")
        end
        format.html { redirect_to authenticated_root_path, alert: "Message too long." }
      end
      return
    end

    rate = GeminiRateTracker.usage
    if rate[:rpd] >= rate[:rpd_limit]
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Daily AI limit reached (#{rate[:rpd_limit]} requests). Resets at midnight."
          render turbo_stream: turbo_stream.replace("toast-container", partial: "shared/toasts")
        end
        format.html { redirect_to authenticated_root_path, alert: "Daily AI limit reached." }
      end
      return
    end

    if rate[:rpm] >= rate[:rpm_limit]
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Slow down — rate limit is #{rate[:rpm_limit]} requests per minute. Wait a moment and try again."
          render turbo_stream: turbo_stream.replace("toast-container", partial: "shared/toasts")
        end
        format.html { redirect_to authenticated_root_path, alert: "Rate limit reached, try again shortly." }
      end
      return
    end

    history << { "role" => "user", "content" => user_text }

    chat_history = trim_for_api(history)
    system_inst = build_system_instruction
    tools = gemini_tools
    refresh_draft_ui = false

    result = GeminiClient.chat(messages: chat_history, system_instruction: system_inst, tools: tools)
    GeminiRateTracker.record!

    # Agentic loop: keep executing tool calls until the model returns a text-only turn.
    # Capped to avoid runaway loops if the model keeps emitting calls.
    iterations = 0
    partials_to_render = []
    while result[:function_calls].any? && iterations < MAX_TOOL_ITERATIONS
      iterations += 1
      calls = result[:function_calls]

      function_responses = calls.map do |fc|
        fn_response = execute_function(fc[:name], fc[:args])
        refresh_draft_ui = true if fn_response[:refresh_draft_ui]
        partials_to_render << fn_response.delete(:partial) if fn_response[:partial]
        { name: fc[:name], response: fn_response }
      end

      chat_history << {
        role: "assistant",
        parts: calls.map { |fc| { functionCall: { name: fc[:name], args: fc[:args] } } }
      }
      chat_history << {
        role: "user",
        parts: function_responses.map { |fr| { functionResponse: { name: fr[:name], response: fr[:response] } } }
      }

      result = GeminiClient.chat(messages: chat_history, system_instruction: system_inst, tools: tools)
      GeminiRateTracker.record!
    end

    assistant_text = result[:text]
    if assistant_text.blank? && iterations >= MAX_TOOL_ITERATIONS
      assistant_text = "I made several changes but stopped to avoid an infinite loop. Let me know if you want me to continue."
    end

    history << { "role" => "assistant", "content" => assistant_text }
    updated_rate = GeminiRateTracker.usage

    respond_to do |format|
      format.turbo_stream do
        streams = [
          turbo_stream.append("ai_chat_messages",
            partial: "ai_chat/message",
            locals: { m: { "role" => "user", "content" => user_text } }
          ),
          turbo_stream.append("ai_chat_messages",
            partial: "ai_chat/message",
            locals: { m: { "role" => "assistant", "content" => assistant_text } }
          ),
          turbo_stream.update("ai_chat_history_wrapper",
            "<input type=\"hidden\" name=\"history\" value=\"#{ERB::Util.html_escape(history.to_json)}\">"),
          turbo_stream.replace("toast-container", partial: "shared/toasts"),
          turbo_stream.update("ai_chat_input", ""),
          turbo_stream.replace("ai_chat_usage", partial: "ai_chat/usage", locals: { rate: updated_rate })
        ]

        partials_to_render.each do |p|
          streams << turbo_stream.append("ai_chat_messages", partial: p[:name], locals: p[:locals])
        end

        if refresh_draft_ui
          start_date = parse_start_date(params[:start_date])
          draft = current_user_draft
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
        @messages = history
        @rate = updated_rate
        render :index
      end
    end
  rescue GeminiClient::RateLimitExhausted => e
    GeminiRateTracker.record!
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = e.message
        render turbo_stream: turbo_stream.replace("toast-container", partial: "shared/toasts")
      end
      format.html { redirect_to authenticated_root_path, alert: e.message }
    end
  rescue => e
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = "AI error: #{e.message}"
        render turbo_stream: turbo_stream.replace("toast-container", partial: "shared/toasts")
      end
      format.html { redirect_to authenticated_root_path, alert: "AI error: #{e.message}" }
    end
  end

  private

  def in_draft_mode?
    current_user_draft.present?
  end

  def parse_start_date(raw)
    raw.present? ? Date.parse(raw) : Date.current
  rescue ArgumentError
    Date.current
  end

  def gemini_tools
    [ {
      functionDeclarations: [
        {
          name: "select_draft",
          description: "Enter draft mode by selecting an existing calendar draft. Use this when the user asks to switch/change drafts or use a specific draft.",
          parameters: {
            type: "OBJECT",
            properties: {
              name: { type: "STRING", description: "Draft name to select (case-insensitive)" },
              draft_id: { type: "INTEGER", description: "Optional draft ID to select" }
            },
            required: []
          }
        },
        {
          name: "create_event",
          description: "Create a new event on the user's calendar. Use this when the user asks to add, schedule, or create an event.",
          parameters: {
            type: "OBJECT",
            properties: {
              title: { type: "STRING", description: "Title of the event" },
              description: { type: "STRING", description: "Optional description or notes" },
              starts_at: { type: "STRING", description: "Start date/time in ISO 8601 format (e.g. 2026-03-20T14:00:00)" },
              ends_at: { type: "STRING", description: "Optional end date/time in ISO 8601 format" },
              duration_minutes: { type: "INTEGER", description: "Optional duration in minutes (used if ends_at is not provided)" },
              location: { type: "STRING", description: "Optional location" },
              color: { type: "STRING", description: "Optional hex color like #34D399" }
            },
            required: [ "title", "starts_at" ]
          }
        },
        {
          name: "edit_event",
          description: "Edit an existing event on the user's calendar. Use this when the user asks to change, update, move, or reschedule an event. Only include fields that should be changed.",
          parameters: {
            type: "OBJECT",
            properties: {
              event_id: { type: "STRING", description: "The ID of the event to edit (can be a draft temp id like d_abc12345)" },
              title: { type: "STRING", description: "New title" },
              description: { type: "STRING", description: "New description" },
              starts_at: { type: "STRING", description: "New start date/time in ISO 8601 format" },
              ends_at: { type: "STRING", description: "New end date/time in ISO 8601 format" },
              duration_minutes: { type: "INTEGER", description: "New duration in minutes" },
              location: { type: "STRING", description: "New location" },
              color: { type: "STRING", description: "New hex color like #34D399" }
            },
            required: [ "event_id" ]
          }
        },
        {
          name: "delete_event",
          description: "Delete an event. Use this when the user asks to remove or delete an event.",
          parameters: {
            type: "OBJECT",
            properties: {
              event_id: { type: "STRING", description: "The ID of the event to delete (can be a draft temp id like d_abc12345)" }
            },
            required: [ "event_id" ]
          }
        },
        {
          name: "create_work_shift",
          description: "Create a new work shift on the user's schedule. Use this when the user asks to add or schedule a work shift or job shift.",
          parameters: {
            type: "OBJECT",
            properties: {
              title: { type: "STRING", description: "Title/name of the shift (e.g. 'Work', 'Barista shift')" },
              start_date: { type: "STRING", description: "Start date in YYYY-MM-DD format" },
              start_time: { type: "STRING", description: "Shift start time in HH:MM 24-hour format (e.g. '09:00')" },
              end_time: { type: "STRING", description: "Shift end time in HH:MM 24-hour format (e.g. '17:00')" },
              description: { type: "STRING", description: "Optional description or notes" },
              location: { type: "STRING", description: "Optional location" },
              color: { type: "STRING", description: "Optional hex color like #34D399" },
              recurring: { type: "BOOLEAN", description: "Whether the shift repeats weekly (default true)" },
              repeat_days: {
                type: "ARRAY",
                items: { type: "INTEGER" },
                description: "Weekday numbers to repeat on: 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat. Required if recurring is true."
              },
              repeat_until: { type: "STRING", description: "Optional end date for recurring shifts in YYYY-MM-DD format" }
            },
            required: [ "title", "start_date", "start_time", "end_time" ]
          }
        },
        {
          name: "edit_work_shift",
          description: "Edit an existing work shift. Use this when the user asks to change, update, or reschedule a work shift. Only include fields that should be changed.",
          parameters: {
            type: "OBJECT",
            properties: {
              shift_id: { type: "STRING", description: "The ID of the work shift to edit (can be a draft temp id like d_abc12345)" },
              title: { type: "STRING", description: "New title" },
              start_date: { type: "STRING", description: "New start date in YYYY-MM-DD format" },
              start_time: { type: "STRING", description: "New start time in HH:MM 24-hour format" },
              end_time: { type: "STRING", description: "New end time in HH:MM 24-hour format" },
              description: { type: "STRING", description: "New description" },
              location: { type: "STRING", description: "New location" },
              color: { type: "STRING", description: "New hex color like #34D399" },
              recurring: { type: "BOOLEAN", description: "Whether the shift repeats weekly" },
              repeat_days: {
                type: "ARRAY",
                items: { type: "INTEGER" },
                description: "New weekday numbers: 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat"
              },
              repeat_until: { type: "STRING", description: "New end date for recurring shifts in YYYY-MM-DD format" }
            },
            required: [ "shift_id" ]
          }
        },
        {
          name: "delete_work_shift",
          description: "Delete a work shift. Use this when the user asks to remove or delete a work shift.",
          parameters: {
            type: "OBJECT",
            properties: {
              shift_id: { type: "STRING", description: "The ID of the work shift to delete (can be a draft temp id like d_abc12345)" }
            },
            required: [ "shift_id" ]
          }
        },
        {
          name: "show_schedule",
          description: "Display the user's calendar schedule as an inline visual in the chat. Use this when the user asks to see, view, or show their schedule or calendar.",
          parameters: {
            type: "OBJECT",
            properties: {
              start_date: { type: "STRING", description: "Start date in YYYY-MM-DD format (defaults to today)" }
            },
            required: []
          }
        },
        {
          name: "show_create_form",
          description: "Display a pre-filled event creation form inline in the chat. Use this instead of create_event when you are missing required information (title or start time). Pass any details you do have so the form is pre-populated for the user to complete.",
          parameters: {
            type: "OBJECT",
            properties: {
              title:            { type: "STRING",  description: "Event title if known" },
              description:      { type: "STRING",  description: "Optional description" },
              starts_at:        { type: "STRING",  description: "Start date/time in ISO 8601 format if known" },
              ends_at:          { type: "STRING",  description: "End date/time in ISO 8601 format if known" },
              duration_minutes: { type: "INTEGER", description: "Duration in minutes if known" },
              location:         { type: "STRING",  description: "Location if known" },
              color:            { type: "STRING",  description: "Hex color like #34D399 if known" }
            },
            required: []
          }
        },
        {
          name: "show_draft_picker",
          description: "Display a draft selection card inline in the chat so the user can pick or create a draft.",
          parameters: { type: "OBJECT", properties: {}, required: [] }
        }
      ]
    } ]
  end

  def execute_function(name, args)
    case name
    when "select_draft"
      select_draft_from_ai(args)
    when "create_event"
      create_event_from_ai(args)
    when "edit_event"
      edit_event_from_ai(args)
    when "delete_event"
      delete_event_from_ai(args)
    when "create_work_shift"
      create_work_shift_from_ai(args)
    when "edit_work_shift"
      edit_work_shift_from_ai(args)
    when "delete_work_shift"
      delete_work_shift_from_ai(args)
    when "show_schedule"
      show_schedule_from_ai(args)
    when "show_create_form"
      show_create_form_from_ai(args)
    when "show_draft_picker"
      show_draft_picker_from_ai
    else
      { error: "Unknown function: #{name}" }
    end
  end

  def select_draft_from_ai(args)
    name = args["name"].to_s
    draft_id = args["draft_id"].presence

    draft =
      if draft_id.present?
        current_user.calendar_drafts.find_by(id: draft_id)
      elsif name.present?
        current_user.calendar_drafts.find_by("LOWER(name) = ?", name.downcase)
      end

    return { success: false, errors: [ "Draft not found" ] } unless draft

    session[:calendar_draft_mode] = true
    session[:active_calendar_draft_id] = draft.id
    @current_user_draft = draft
    @current_user_drafts = nil

    { success: true, draft_id: draft.id, name: draft.name, refresh_draft_ui: true }
  end

  def create_event_from_ai(args)
    if in_draft_mode?
      data = {
        title: args["title"],
        description: args["description"],
        starts_at: args["starts_at"],
        ends_at: args["ends_at"],
        duration_minutes: args["duration_minutes"],
        location: args["location"],
        color: args["color"]
      }.compact

      event = current_user.events.new(data)
      return { success: false, errors: event.errors.full_messages } unless event.valid?

      temp_id = current_user_draft.add_create("event", data)
      return { success: true, event_id: temp_id, title: data[:title], starts_at: data[:starts_at], refresh_draft_ui: true }
    end

    event = current_user.events.new(
      title: args["title"],
      description: args["description"],
      starts_at: Time.zone.parse(args["starts_at"]),
      ends_at: args["ends_at"].present? ? Time.zone.parse(args["ends_at"]) : nil,
      duration_minutes: args["duration_minutes"],
      location: args["location"],
      color: args["color"],
      project_id: nil
    )

    if event.save
      { success: true, event_id: event.id, title: event.title, starts_at: event.starts_at.iso8601 }
    else
      { success: false, errors: event.errors.full_messages }
    end
  end

  def edit_event_from_ai(args)
    event_id = args["event_id"].to_s
    return { success: false, errors: [ "Event ID is required" ] } if event_id.blank?

    if in_draft_mode?
      if event_id.start_with?("d_")
        op = current_user_draft&.find_create_op("event", event_id)
        return { success: false, errors: [ "Draft event not found" ] } unless op

        base = op.fetch("data", {})
        updates = {}
        updates["title"] = args["title"] if args["title"].present?
        updates["description"] = args["description"] if args.key?("description")
        updates["starts_at"] = args["starts_at"] if args["starts_at"].present?
        updates["ends_at"] = args["ends_at"] if args.key?("ends_at")
        updates["duration_minutes"] = args["duration_minutes"] if args.key?("duration_minutes")
        updates["location"] = args["location"] if args.key?("location")
        updates["color"] = args["color"] if args["color"].present?

        merged = base.merge(updates)
        event = current_user.events.new(merged)
        return { success: false, errors: event.errors.full_messages } unless event.valid?

        updated = current_user_draft&.update_create("event", event_id, merged)
        return { success: false, errors: [ "Draft event not found" ] } unless updated

        return { success: true, event_id: event_id, title: merged["title"], refresh_draft_ui: true }
      end

      event = current_user.events.find_by(id: event_id)
      return { success: false, errors: [ "Event not found" ] } unless event
      return { success: false, errors: [ "AI can't edit group events." ] } if event.project_id.present?

      updates = {}
      updates[:title] = args["title"] if args["title"].present?
      updates[:description] = args["description"] if args.key?("description")
      updates[:starts_at] = args["starts_at"] if args["starts_at"].present?
      updates[:ends_at] = args["ends_at"] if args.key?("ends_at")
      updates[:duration_minutes] = args["duration_minutes"] if args.key?("duration_minutes")
      updates[:location] = args["location"] if args.key?("location")
      updates[:color] = args["color"] if args["color"].present?

      event.assign_attributes(updates)
      return { success: false, errors: event.errors.full_messages } unless event.valid?

      current_user_draft.add_update("event", event.id, updates)
      return { success: true, event_id: event.id, title: event.title, refresh_draft_ui: true }
    end

    event = current_user.events.find_by(id: event_id)
    return { success: false, errors: [ "Event not found" ] } unless event
    return { success: false, errors: [ "AI can't edit group events." ] } if event.project_id.present?

    updates = {}
    updates[:title] = args["title"] if args["title"].present?
    updates[:description] = args["description"] if args.key?("description")
    updates[:starts_at] = Time.zone.parse(args["starts_at"]) if args["starts_at"].present?
    updates[:ends_at] = Time.zone.parse(args["ends_at"]) if args["ends_at"].present?
    updates[:duration_minutes] = args["duration_minutes"] if args["duration_minutes"].present?
    updates[:location] = args["location"] if args.key?("location")
    updates[:color] = args["color"] if args["color"].present?

    if event.update(updates)
      { success: true, event_id: event.id, title: event.title, starts_at: event.starts_at.iso8601 }
    else
      { success: false, errors: event.errors.full_messages }
    end
  end

  def delete_event_from_ai(args)
    event_id = args["event_id"].to_s
    return { success: false, errors: [ "Event ID is required" ] } if event_id.blank?

    if in_draft_mode?
      if event_id.start_with?("d_")
        deleted = current_user_draft&.delete_create("event", event_id)
        return { success: false, errors: [ "Draft event not found" ] } unless deleted

        return { success: true, event_id: event_id, refresh_draft_ui: true }
      end

      event = current_user.events.find_by(id: event_id)
      return { success: false, errors: [ "Event not found" ] } unless event
      return { success: false, errors: [ "AI can't delete group events." ] } if event.project_id.present?

      current_user_draft.add_delete("event", event.id)
      return { success: true, event_id: event.id, title: event.title, refresh_draft_ui: true }
    end

    event = current_user.events.find_by(id: event_id)
    return { success: false, errors: [ "Event not found" ] } unless event
    return { success: false, errors: [ "AI can't delete group events." ] } if event.project_id.present?

    title = event.title
    event.destroy
    { success: true, event_id: event_id, title: title }
  end

  def create_work_shift_from_ai(args)
    if in_draft_mode?
      data = {
        title: args["title"],
        description: args["description"],
        start_date: args["start_date"],
        start_time: args["start_time"],
        end_time: args["end_time"],
        location: args["location"],
        color: args["color"].presence || "#34D399",
        recurring: args.key?("recurring") ? args["recurring"] : true,
        repeat_days: args["repeat_days"] || [],
        repeat_until: args["repeat_until"]
      }.compact

      shift = current_user.work_shifts.new(data)
      return { success: false, errors: shift.errors.full_messages } unless shift.valid?

      temp_id = current_user_draft.add_create("shift", data)
      return { success: true, shift_id: temp_id, title: data[:title], start_date: data[:start_date], refresh_draft_ui: true }
    end

    shift = current_user.work_shifts.new(
      title: args["title"],
      description: args["description"],
      start_date: Date.parse(args["start_date"]),
      start_time: args["start_time"],
      end_time: args["end_time"],
      location: args["location"],
      color: args["color"].presence || "#34D399",
      recurring: args.key?("recurring") ? args["recurring"] : true,
      repeat_days: args["repeat_days"] || [],
      repeat_until: args["repeat_until"].present? ? Date.parse(args["repeat_until"]) : nil
    )

    if shift.save
      { success: true, shift_id: shift.id, title: shift.title, start_date: shift.start_date.iso8601 }
    else
      { success: false, errors: shift.errors.full_messages }
    end
  end

  def edit_work_shift_from_ai(args)
    shift_id = args["shift_id"].to_s
    return { success: false, errors: [ "Work shift ID is required" ] } if shift_id.blank?

    if in_draft_mode?
      if shift_id.start_with?("d_")
        op = current_user_draft&.find_create_op("shift", shift_id)
        return { success: false, errors: [ "Draft shift not found" ] } unless op

        base = op.fetch("data", {})
        updates = {}
        updates["title"] = args["title"] if args["title"].present?
        updates["description"] = args["description"] if args.key?("description")
        updates["start_date"] = args["start_date"] if args["start_date"].present?
        updates["start_time"] = args["start_time"] if args["start_time"].present?
        updates["end_time"] = args["end_time"] if args["end_time"].present?
        updates["location"] = args["location"] if args.key?("location")
        updates["color"] = args["color"] if args["color"].present?
        updates["recurring"] = args["recurring"] if args.key?("recurring")
        updates["repeat_days"] = args["repeat_days"] if args.key?("repeat_days")
        updates["repeat_until"] = args["repeat_until"] if args.key?("repeat_until")

        merged = base.merge(updates)
        shift = current_user.work_shifts.new(merged)
        return { success: false, errors: shift.errors.full_messages } unless shift.valid?

        updated = current_user_draft&.update_create("shift", shift_id, merged)
        return { success: false, errors: [ "Draft shift not found" ] } unless updated

        return { success: true, shift_id: shift_id, title: merged["title"], refresh_draft_ui: true }
      end

      shift = current_user.work_shifts.find_by(id: shift_id)
      return { success: false, errors: [ "Work shift not found" ] } unless shift

      updates = {}
      updates[:title] = args["title"] if args["title"].present?
      updates[:description] = args["description"] if args.key?("description")
      updates[:start_date] = args["start_date"] if args["start_date"].present?
      updates[:start_time] = args["start_time"] if args["start_time"].present?
      updates[:end_time] = args["end_time"] if args["end_time"].present?
      updates[:location] = args["location"] if args.key?("location")
      updates[:color] = args["color"] if args["color"].present?
      updates[:recurring] = args["recurring"] if args.key?("recurring")
      updates[:repeat_days] = args["repeat_days"] if args.key?("repeat_days")
      updates[:repeat_until] = args["repeat_until"] if args.key?("repeat_until")

      shift.assign_attributes(updates)
      return { success: false, errors: shift.errors.full_messages } unless shift.valid?

      current_user_draft.add_update("shift", shift.id, updates)
      return { success: true, shift_id: shift.id, title: shift.title, refresh_draft_ui: true }
    end

    shift = current_user.work_shifts.find_by(id: shift_id)
    return { success: false, errors: [ "Work shift not found" ] } unless shift

    updates = {}
    updates[:title] = args["title"] if args["title"].present?
    updates[:description] = args["description"] if args.key?("description")
    updates[:start_date] = Date.parse(args["start_date"]) if args["start_date"].present?
    updates[:start_time] = args["start_time"] if args["start_time"].present?
    updates[:end_time] = args["end_time"] if args["end_time"].present?
    updates[:location] = args["location"] if args.key?("location")
    updates[:color] = args["color"] if args["color"].present?
    updates[:recurring] = args["recurring"] if args.key?("recurring")
    updates[:repeat_days] = args["repeat_days"] if args.key?("repeat_days")
    updates[:repeat_until] = args["repeat_until"].present? ? Date.parse(args["repeat_until"]) : nil if args.key?("repeat_until")

    if shift.update(updates)
      { success: true, shift_id: shift.id, title: shift.title }
    else
      { success: false, errors: shift.errors.full_messages }
    end
  end

  def delete_work_shift_from_ai(args)
    shift_id = args["shift_id"].to_s
    return { success: false, errors: [ "Work shift ID is required" ] } if shift_id.blank?

    if in_draft_mode?
      if shift_id.start_with?("d_")
        deleted = current_user_draft&.delete_create("shift", shift_id)
        return { success: false, errors: [ "Draft shift not found" ] } unless deleted

        return { success: true, shift_id: shift_id, refresh_draft_ui: true }
      end

      shift = current_user.work_shifts.find_by(id: shift_id)
      return { success: false, errors: [ "Work shift not found" ] } unless shift

      current_user_draft.add_delete("shift", shift.id)
      return { success: true, shift_id: shift.id, title: shift.title, refresh_draft_ui: true }
    end

    shift = current_user.work_shifts.find_by(id: shift_id)
    return { success: false, errors: [ "Work shift not found" ] } unless shift

    title = shift.title
    shift.destroy
    { success: true, shift_id: shift_id, title: title }
  end

  def show_schedule_from_ai(args)
    start_date  = args["start_date"].present? ? Date.parse(args["start_date"]) : Date.current
    week_start  = start_date.beginning_of_week
    range_end   = (week_start + 13.days).end_of_day
    draft       = current_user_draft
    occurrences = calendar_occurrences_for_range(week_start.beginning_of_day, range_end, draft: draft)
    { success: true, partial: { name: "ai_chat/ai_schedule", locals: { occurrences: occurrences, start_date: start_date } } }
  end

  def show_create_form_from_ai(args)
    attrs = { color: args["color"].presence || "#34D399" }
    attrs[:title]            = args["title"]            if args["title"].present?
    attrs[:description]      = args["description"]      if args["description"].present?
    attrs[:location]         = args["location"]         if args["location"].present?
    attrs[:duration_minutes] = args["duration_minutes"] if args["duration_minutes"].present?
    attrs[:starts_at]        = Time.zone.parse(args["starts_at"]) rescue nil if args["starts_at"].present?
    attrs[:ends_at]          = Time.zone.parse(args["ends_at"])   rescue nil if args["ends_at"].present?
    event = current_user.events.new(attrs)
    { success: true, partial: { name: "ai_chat/ai_create_form", locals: { event: event } } }
  end

  def show_draft_picker_from_ai
    { success: true, partial: { name: "ai_chat/draft_select_form", locals: { drafts: current_user_drafts.to_a, start_date: Date.current.iso8601 } } }
  end

  def build_system_instruction
    user = current_user
    name = user.email.split("@").first.gsub(/[._]/, " ").titleize

    # Gather upcoming events (next 14 days)
    upcoming_events = user.events
      .where("starts_at >= ? AND starts_at <= ?", Time.current, 14.days.from_now)
      .order(:starts_at)
      .limit(30)

    # Gather courses
    courses = user.courses.includes(:course_items)

    # Gather upcoming course items (next 14 days)
    upcoming_items = CourseItem
      .where(course: courses)
      .where("due_at >= ? AND due_at <= ?", Time.current, 14.days.from_now)
      .order(:due_at)
      .limit(30)

    parts = []
    parts << "You are a helpful academic assistant for a calendar and course management app called CLEAR."
    parts << "The user's name is #{name} (email: #{user.email}). Address them by their first name."
    parts << "Today's date is #{Date.today.strftime('%A, %B %d, %Y')}."
    if current_user_draft.present?
      parts << "Current draft is \"#{current_user_draft.name}\" (ID: #{current_user_draft.id})."
    else
      parts << "Current draft is none (Main Calendar)."
    end

    drafts = current_user_drafts.to_a
    if drafts.any?
      parts << "Available drafts: " + drafts.map { |d| "#{d.name} (ID: #{d.id})" }.join(", ")
    end

    if courses.any?
      course_lines = courses.map do |c|
        line = "- #{c.title}"
        line += " (#{c.code})" if c.code.present?
        line += " with #{c.professor || c.instructor}" if c.professor.present? || c.instructor.present?
        line += ", #{c.meeting_days}" if c.meeting_days.present?
        line += " #{c.start_time&.strftime('%l:%M%P')}-#{c.end_time&.strftime('%l:%M%P')}" if c.start_time.present?
        line += " at #{c.location}" if c.location.present?
        line += " (#{c.term})" if c.term.present?
        line
      end
      if current_user_draft.present?
        current_user_draft.operations.select { |o| o["type"] == "create" && o["model"] == "course" }.each do |op|
          d = op["data"]
          line = "- [DRAFT] #{d["title"].presence || "(untitled)"}"
          line += " (#{d["code"]})" if d["code"].present?
          line += " #{d["meeting_days"]}" if d["meeting_days"].present?
          line += " #{d["start_time"]}–#{d["end_time"]}" if d["start_time"].present?
          course_lines << line
        end
      end
      parts << "\nThe user's courses:\n#{course_lines.join("\n")}"
    end

    if upcoming_events.any?
      personal, group = upcoming_events.partition { |e| e.project_id.blank? }

      if personal.any?
        event_lines = personal.map do |e|
          line = "- [ID:#{e.id}] #{e.title} on #{e.starts_at.strftime('%a %b %d at %l:%M%P')}"
          line += " at #{e.location}" if e.location.present?
          line += " — #{e.description}" if e.description.present?
          line
        end

        if current_user_draft.present?
          current_user_draft.operations.select { |o| o["type"] == "create" && o["model"] == "event" }.each do |op|
            d = op["data"]
            starts_at = d["starts_at"].present? ? (Time.zone.parse(d["starts_at"]) rescue nil) : nil
            next unless starts_at && starts_at >= Time.current && starts_at <= 14.days.from_now
            line = "- [ID:#{op["temp_id"]}] [DRAFT] #{d["title"].presence || "(untitled)"} on #{starts_at.strftime('%a %b %d at %l:%M%P')}"
            line += " at #{d["location"]}" if d["location"].present?
            event_lines << line
          end
        end

        parts << "\nUpcoming events (next 14 days):\n#{event_lines.join("\n")}"
      end

      if group.any?
        group_lines = group.map do |e|
          line = "- [ID:#{e.id}] #{e.title} on #{e.starts_at.strftime('%a %b %d at %l:%M%P')} (GROUP)"
          line += " at #{e.location}" if e.location.present?
          line += " — #{e.description}" if e.description.present?
          line
        end
        parts << "\nUpcoming group events (project_id present; read-only):\n#{group_lines.join("\n")}"
      end
    end

    if upcoming_items.any?
      item_lines = upcoming_items.map do |ci|
        "- #{ci.display_title} due #{ci.due_at.strftime('%a %b %d at %l:%M%P')}"
      end
      parts << "\nUpcoming assignments & deadlines (next 14 days):\n#{item_lines.join("\n")}"
    end

    # Gather active work shifts
    work_shifts = user.work_shifts.active.ordered

    if work_shifts.any?
      shift_lines = work_shifts.map do |s|
        line = "- [ID:#{s.id}] #{s.title} #{s.formatted_time_range}"
        line += " (#{s.repeat_days_labels})" if s.recurring? && s.repeat_days.any?
        line += " until #{s.repeat_until.strftime('%b %d, %Y')}" if s.repeat_until.present?
        line += " at #{s.location}" if s.location.present?
        line
      end
      if current_user_draft.present?
        current_user_draft.operations.select { |o| o["type"] == "create" && o["model"] == "shift" }.each do |op|
          d = op["data"]
          line = "- [ID:#{op["temp_id"]}] [DRAFT] #{d["title"].presence || "(untitled)"}"
          line += " #{d["start_time"]}–#{d["end_time"]}" if d["start_time"].present?
          line += " starting #{d["start_date"]}" if d["start_date"].present?
          line += " at #{d["location"]}" if d["location"].present?
          shift_lines << line
        end
      end
      parts << "\nUser's work shifts:\n#{shift_lines.join("\n")}"
    end

    # Pre-compute blocked slots per day for the next 14 days
    blocked = Hash.new { |h, k| h[k] = [] }
    range = (Date.current..14.days.from_now.to_date)

    upcoming_events.each do |e|
      next unless e.starts_at && e.ends_at
      blocked[e.starts_at.to_date] << "#{e.starts_at.strftime("%-I:%M%P")}–#{e.ends_at.strftime("%-I:%M%P")} (#{e.title})"
    end

    courses.each do |c|
      next unless c.start_time && c.end_time
      days = Array(c.repeat_days).map(&:to_i)
      range.each do |d|
        next unless days.include?(d.wday)
        next if c.respond_to?(:start_date) && c.start_date.present? && d < c.start_date
        next if c.respond_to?(:end_date)   && c.end_date.present?   && d > c.end_date
        blocked[d] << "#{c.start_time.strftime("%-I:%M%P")}–#{c.end_time.strftime("%-I:%M%P")} (#{c.title} course)"
      end
    end

    work_shifts.each do |s|
      next unless s.start_time && s.end_time
      range.each do |d|
        if s.recurring?
          next unless Array(s.repeat_days).map(&:to_i).include?(d.wday)
          next if d < s.start_date
          next if s.repeat_until.present? && d > s.repeat_until
        else
          next unless d == s.start_date
        end
        blocked[d] << "#{s.start_time.strftime("%-I:%M%P")}–#{s.end_time.strftime("%-I:%M%P")} (#{s.title} shift)"
      end
    end

    if blocked.any?
      blocked_lines = blocked.sort.map { |day, slots| "  #{day.strftime("%a %b %-d")}: #{slots.sort.join(", ")}" }
      parts << "\nOccupied time slots — do NOT schedule anything overlapping these:\n#{blocked_lines.join("\n")}"
    end

    if current_user_draft.present?
      draft_lines = []
      current_user_draft.operations.each do |op|
        data  = op["data"] || {}
        model = op["model"]
        case op["type"]
        when "create"
          case model
          when "event"
            starts_at = data["starts_at"].present? ? (Time.zone.parse(data["starts_at"]) rescue nil) : nil
            line = "- ADD event [#{op["temp_id"]}]: \"#{data["title"].presence || "(untitled)"}\""
            line += " on #{starts_at.strftime("%a %b %-d at %-I:%M%P")}" if starts_at
            line += " for #{data["duration_minutes"]} min" if data["duration_minutes"].present?
            line += " at #{data["location"]}" if data["location"].present?
            line += " — #{data["description"]}" if data["description"].present?
          when "shift"
            line = "- ADD work shift [#{op["temp_id"]}]: \"#{data["title"].presence || "(untitled)"}\""
            line += " on #{data["start_date"]}" if data["start_date"].present?
            line += " #{data["start_time"]}–#{data["end_time"]}" if data["start_time"].present?
            line += " at #{data["location"]}" if data["location"].present?
          when "course"
            line = "- ADD course [#{op["temp_id"]}]: \"#{data["title"].presence || "(untitled)"}\""
          else
            next
          end
          draft_lines << line
        when "update"
          case model
          when "event"
            record = user.events.find_by(id: op["id"])
            label  = record ? "\"#{record.title}\" [ID:#{op["id"]}]" : "event ID #{op["id"]}"
            changes = data.map do |k, v|
              k == "starts_at" ? "#{k}: #{(Time.zone.parse(v.to_s) rescue v)&.strftime("%a %b %-d at %-I:%M%P")}" : "#{k}: #{v}"
            end.join(", ")
            draft_lines << "- EDIT event #{label} — #{changes}"
          when "shift"
            record = user.work_shifts.find_by(id: op["id"])
            label  = record ? "\"#{record.title}\" [ID:#{op["id"]}]" : "shift ID #{op["id"]}"
            draft_lines << "- EDIT work shift #{label} — #{data.map { |k, v| "#{k}: #{v}" }.join(", ")}"
          when "course"
            record = user.courses.find_by(id: op["id"])
            label  = record ? "\"#{record.title}\" [ID:#{op["id"]}]" : "course ID #{op["id"]}"
            draft_lines << "- EDIT course #{label} — #{data.map { |k, v| "#{k}: #{v}" }.join(", ")}"
          end
        when "delete"
          case model
          when "event"
            record = user.events.find_by(id: op["id"])
            draft_lines << "- REMOVE event: \"#{record&.title || "ID #{op["id"]}"}\" [ID:#{op["id"]}]"
          when "shift"
            record = user.work_shifts.find_by(id: op["id"])
            draft_lines << "- REMOVE work shift: \"#{record&.title || "ID #{op["id"]}"}\" [ID:#{op["id"]}]"
          when "course"
            record = user.courses.find_by(id: op["id"])
            draft_lines << "- REMOVE course: \"#{record&.title || "ID #{op["id"]}"}\" [ID:#{op["id"]}]"
          end
        end
      end

      if draft_lines.any?
        parts << "\nThis draft (\"#{current_user_draft.name}\") has the following pending changes on top of the main calendar:\n#{draft_lines.join("\n")}"
        parts << "Treat these draft changes as the user's current working schedule — additions are real commitments, " \
                 "removals are gone, and edits reflect the new values. Give advice, flag conflicts, and answer " \
                 "questions as if this is simply their calendar. Do NOT volunteer that something is a draft or mention " \
                 "the draft/main distinction unless the user explicitly asks to compare the draft against the main " \
                 "calendar or asks what will change when the draft is applied."
      else
        parts << "\nThis draft (\"#{current_user_draft.name}\") has no pending changes yet — it currently mirrors the main calendar."
      end
    end

    parts << "\nUse this context to give personalized advice, reminders, and insights. " \
             "You can suggest study strategies, flag busy days, warn about upcoming deadlines, " \
             "and help with time management. Keep responses concise and friendly."
    parts << "\nYou can create events using create_event and edit existing events using edit_event. " \
             "When the user asks to schedule or add something, use create_event. " \
             "When the user asks to change, move, reschedule, or update an event, use edit_event with the event's ID. " \
             "Each event listed above has an [ID:...] you can use. Always confirm what was created or changed."
    parts << "\nWhen a single user request requires MULTIPLE changes (e.g. \"create three events\", \"add a shift " \
             "and an event\", \"reschedule these two\"), call the tools as many times as needed in the same turn — " \
             "you may emit multiple function calls. Do not stop after one tool call if more are needed to fulfill " \
             "the request. Only produce a final text reply after all required tool calls have been made."
    parts << "\nCreating events — decision rule: " \
             "If the user's request gives you BOTH a title AND a start time, call create_event directly. " \
             "If either is missing or ambiguous, call show_create_form instead, passing every detail you DO have " \
             "(title, starts_at, location, color, etc.) so the form is pre-filled for the user to complete. " \
             "Never ask the user to provide more text before showing the form — show it immediately with whatever you have."
    parts << "\nGroup events (project_id present) are read-only: NEVER create, edit, delete, or reschedule any event that has a project_id. " \
             "If the user asks to change a group event, tell them you can only assist with personal calendar events."
    parts << "\nOther inline UI tools: use show_schedule to display the user's calendar visually " \
             "(prefer calling it after any calendar change so the user can see the result), " \
             "and show_draft_picker to let the user interactively pick or create a draft."
    parts << "\nYou can also manage work shifts: create with create_work_shift, edit with edit_work_shift, " \
             "or delete with delete_work_shift. Each work shift listed above has an [ID:...] you can use. " \
             "For recurring shifts, repeat_days uses weekday numbers (0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat)."

    parts << "\n--- SCOPE & GUARDRAILS ---"
    parts << "You are strictly an academic/calendar planning assistant for CLEAR. Your purpose is to help the user " \
             "manage their courses, events, work shifts, deadlines, drafts, and study planning."
    parts << "ALWAYS allowed: brief greetings and small talk (e.g. \"hi\", \"thanks\", \"how are you\") — keep these " \
             "to one short sentence. Using any of the provided tools (create_event, edit_event, delete_event, " \
             "create_work_shift, edit_work_shift, delete_work_shift, select_draft) to help the user plan. " \
             "Answering questions about their schedule, courses, drafts, deadlines, study strategy, and time management."
    parts << "REFUSE (politely, in one or two sentences) any request that is not related to academic planning or " \
             "the calendar, especially requests that would consume excessive tokens. Examples to refuse: writing " \
             "stories, poems, essays, songs, jokes, or other creative content; counting, listing, or enumerating " \
             "long sequences (e.g. \"count to 1,000,000\", \"list every U.S. city\"); generating code unrelated to " \
             "scheduling; long translations; long summaries of unrelated content; role-play; trivia or general-" \
             "knowledge questions unrelated to the user's schedule; repeating text; \"keep going forever\" style requests."
    parts << "When refusing, do NOT comply partially. Briefly say you can only help with academic planning and " \
             "scheduling, and suggest one concrete planning action you could do instead. Do not apologize at length."
    parts << "Keep ALL responses concise. Most replies should be under 4 sentences. Never produce long lists, " \
             "long enumerations, or large blocks of text. If a tool can fulfill the user's planning request, " \
             "prefer the tool over a long written explanation."

    parts.join("\n")
  end

  API_HISTORY_LIMIT = 20
  MAX_USER_MESSAGE_CHARS = 2000
  MAX_TOOL_ITERATIONS = 8

  def trim_for_api(history)
    trimmed = if history.length > API_HISTORY_LIMIT
      [ { role: "user", content: "Previous conversation context has been trimmed for efficiency." },
        { role: "assistant", content: "Understood, I'll continue from the recent messages." } ] +
        history.last(API_HISTORY_LIMIT).map { |m| { role: m["role"], content: m["content"] } }
    else
      history.map { |m| { role: m["role"], content: m["content"] } }
    end
    trimmed
  end

  def parse_history(raw)
    return [] if raw.blank?
    arr = JSON.parse(raw)
    return [] unless arr.is_a?(Array)
    arr = arr.select { |m| m.is_a?(Hash) && m["role"].present? && m["content"].present? }
    arr.last(50)
  rescue JSON::ParserError
    []
  end
end
