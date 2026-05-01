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
    fn_response = nil
    refresh_draft_ui = false

    result = GeminiClient.chat(messages: chat_history, system_instruction: system_inst, tools: tools)
    GeminiRateTracker.record!

    # Handle function calls
    if result[:function_call]
      fc = result[:function_call]
      fn_response = execute_function(fc[:name], fc[:args])
      refresh_draft_ui = fn_response[:refresh_draft_ui]

      chat_history << { role: "assistant", parts: [ { functionCall: { name: fc[:name], args: fc[:args] } } ] }

      final = GeminiClient.continue_with_function_response(
        messages: chat_history,
        function_name: fc[:name],
        response_data: fn_response,
        system_instruction: system_inst,
        tools: tools
      )
      GeminiRateTracker.record!
      assistant_text = final[:text]
    else
      assistant_text = result[:text]
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
      color: args["color"]
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

      current_user_draft.add_delete("event", event.id)
      return { success: true, event_id: event.id, title: event.title, refresh_draft_ui: true }
    end

    event = current_user.events.find_by(id: event_id)
    return { success: false, errors: [ "Event not found" ] } unless event

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
      parts << "\nThe user's courses:\n#{course_lines.join("\n")}"
    end

    if upcoming_events.any?
      event_lines = upcoming_events.map do |e|
        line = "- [ID:#{e.id}] #{e.title} on #{e.starts_at.strftime('%a %b %d at %l:%M%P')}"
        line += " at #{e.location}" if e.location.present?
        line += " — #{e.description}" if e.description.present?
        line
      end
      parts << "\nUpcoming events (next 14 days):\n#{event_lines.join("\n")}"
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
      parts << "\nUser's work shifts:\n#{shift_lines.join("\n")}"
    end

    parts << "\nUse this context to give personalized advice, reminders, and insights. " \
             "You can suggest study strategies, flag busy days, warn about upcoming deadlines, " \
             "and help with time management. Keep responses concise and friendly."
    parts << "\nYou can create events using create_event and edit existing events using edit_event. " \
             "When the user asks to schedule or add something, use create_event. " \
             "When the user asks to change, move, reschedule, or update an event, use edit_event with the event's ID. " \
             "Each event listed above has an [ID:...] you can use. Always confirm what was created or changed."
    parts << "\nYou can also manage work shifts: create with create_work_shift, edit with edit_work_shift, " \
             "or delete with delete_work_shift. Each work shift listed above has an [ID:...] you can use. " \
             "For recurring shifts, repeat_days uses weekday numbers (0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat)."

    parts.join("\n")
  end

  API_HISTORY_LIMIT = 20

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
