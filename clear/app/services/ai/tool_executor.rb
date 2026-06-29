module Ai
  # Executes AI tool calls in the context of the current user/draft/session.
  # Instantiated once per chat turn via Ai::ChatContext.
  class ToolExecutor
    def initialize(ctx)
      @ctx     = ctx
      @user    = ctx.user
      @session = ctx.session
    end

    def execute(name, args)
      result = case name
      when "select_draft"       then select_draft(args)
      when "create_event"       then create_event(args)
      when "edit_event"         then edit_event(args)
      when "delete_event"       then delete_event(args)
      when "create_work_shift"  then create_work_shift(args)
      when "edit_work_shift"    then edit_work_shift(args)
      when "delete_work_shift"  then delete_work_shift(args)
      when "show_schedule"      then show_schedule(args)
      when "show_create_form"   then show_create_form(args)
      when "show_draft_picker"  then show_draft_picker
      when "propose_routine"    then propose_routine(args)
      else
        { error: "Unknown tool: #{name}" }
      end

      if result[:refresh_draft_ui]
        @ctx.refresh_draft_ui = true
        result = result.except(:refresh_draft_ui)
      end
      if result[:partial]
        @ctx.add_partial(result[:partial][:name], result[:partial][:locals])
        result = result.except(:partial)
      end

      result
    end

    private

    def draft
      @ctx.draft
    end

    def in_draft_mode?
      draft.present?
    end

    def select_draft(args)
      name_arg = args["name"].to_s
      draft_id = args["draft_id"].presence

      found =
        if draft_id.present?
          @user.calendar_drafts.find_by(id: draft_id)
        elsif name_arg.present?
          @user.calendar_drafts.find_by("LOWER(name) = ?", name_arg.downcase)
        end

      return { success: false, errors: [ "Draft not found" ] } unless found

      @session[:calendar_draft_mode] = true
      @session[:active_calendar_draft_id] = found.id
      @ctx.draft = found

      { success: true, draft_id: found.id, name: found.name, refresh_draft_ui: true }
    end

    def create_event(args)
      if in_draft_mode?
        data = {
          title: args["title"], description: args["description"],
          starts_at: args["starts_at"], ends_at: args["ends_at"],
          duration_minutes: args["duration_minutes"], location: args["location"],
          color: args["color"]
        }.compact
        event = @user.events.new(data)
        return { success: false, errors: event.errors.full_messages } unless event.valid?
        temp_id = draft.add_create("event", data)
        return { success: true, event_id: temp_id, title: data[:title], starts_at: data[:starts_at], refresh_draft_ui: true }
      end

      event = @user.events.new(
        title: args["title"], description: args["description"],
        starts_at: (Time.zone.parse(args["starts_at"]) rescue nil),
        ends_at: args["ends_at"].present? ? (Time.zone.parse(args["ends_at"]) rescue nil) : nil,
        duration_minutes: args["duration_minutes"], location: args["location"],
        color: args["color"], project_id: nil
      )
      if event.save
        { success: true, event_id: event.id, title: event.title, starts_at: event.starts_at.iso8601 }
      else
        { success: false, errors: event.errors.full_messages }
      end
    end

    def edit_event(args)
      event_id = args["event_id"].to_s
      return { success: false, errors: [ "Event ID is required" ] } if event_id.blank?

      if in_draft_mode?
        if event_id.start_with?("d_")
          op = draft&.find_create_op("event", event_id)
          return { success: false, errors: [ "Draft event not found" ] } unless op
          base = op.fetch("data", {})
          updates = filter_updates(args, %w[title description starts_at ends_at duration_minutes location color])
          merged = base.merge(updates)
          event = @user.events.new(merged)
          return { success: false, errors: event.errors.full_messages } unless event.valid?
          return { success: false, errors: [ "Draft event not found" ] } unless draft&.update_create("event", event_id, merged)
          return { success: true, event_id: event_id, title: merged["title"], refresh_draft_ui: true }
        end

        event = @user.events.find_by(id: event_id)
        return { success: false, errors: [ "Event not found" ] } unless event
        return { success: false, errors: [ "AI can't edit group events." ] } if event.project_id.present?
        updates = filter_updates(args, %w[title description starts_at ends_at duration_minutes location color])
        event.assign_attributes(updates.transform_keys(&:to_sym))
        return { success: false, errors: event.errors.full_messages } unless event.valid?
        draft.add_update("event", event.id, updates)
        return { success: true, event_id: event.id, title: event.title, refresh_draft_ui: true }
      end

      event = @user.events.find_by(id: event_id)
      return { success: false, errors: [ "Event not found" ] } unless event
      return { success: false, errors: [ "AI can't edit group events." ] } if event.project_id.present?
      updates = {}
      updates[:title]            = args["title"]                          if args.key?("title") && args["title"].present?
      updates[:description]      = args["description"]                    if args.key?("description")
      updates[:starts_at]        = (Time.zone.parse(args["starts_at"]) rescue nil)    if args["starts_at"].present?
      updates[:ends_at]          = (Time.zone.parse(args["ends_at"])   rescue nil)    if args["ends_at"].present?
      updates[:duration_minutes] = args["duration_minutes"]               if args["duration_minutes"].present?
      updates[:location]         = args["location"]                       if args.key?("location")
      updates[:color]            = args["color"]                          if args["color"].present?
      if event.update(updates)
        { success: true, event_id: event.id, title: event.title, starts_at: event.starts_at.iso8601 }
      else
        { success: false, errors: event.errors.full_messages }
      end
    end

    def delete_event(args)
      event_id = args["event_id"].to_s
      return { success: false, errors: [ "Event ID is required" ] } if event_id.blank?

      if in_draft_mode?
        if event_id.start_with?("d_")
          deleted = draft&.delete_create("event", event_id)
          return { success: false, errors: [ "Draft event not found" ] } unless deleted
          return { success: true, event_id: event_id, refresh_draft_ui: true }
        end
        event = @user.events.find_by(id: event_id)
        return { success: false, errors: [ "Event not found" ] } unless event
        return { success: false, errors: [ "AI can't delete group events." ] } if event.project_id.present?
        draft.add_delete("event", event.id)
        return { success: true, event_id: event.id, title: event.title, refresh_draft_ui: true }
      end

      event = @user.events.find_by(id: event_id)
      return { success: false, errors: [ "Event not found" ] } unless event
      return { success: false, errors: [ "AI can't delete group events." ] } if event.project_id.present?
      title = event.title
      event.destroy
      { success: true, event_id: event_id, title: title }
    end

    def create_work_shift(args)
      if in_draft_mode?
        data = {
          title: args["title"], description: args["description"],
          start_date: args["start_date"], start_time: args["start_time"],
          end_time: args["end_time"], location: args["location"],
          color: args["color"].presence || "#34D399",
          recurring: args.key?("recurring") ? args["recurring"] : true,
          repeat_days: args["repeat_days"] || [],
          repeat_until: args["repeat_until"]
        }.compact
        shift = @user.work_shifts.new(data)
        return { success: false, errors: shift.errors.full_messages } unless shift.valid?
        temp_id = draft.add_create("shift", data)
        return { success: true, shift_id: temp_id, title: data[:title], start_date: data[:start_date], refresh_draft_ui: true }
      end

      shift = @user.work_shifts.new(
        title: args["title"], description: args["description"],
        start_date: (Date.parse(args["start_date"]) rescue nil),
        start_time: args["start_time"], end_time: args["end_time"],
        location: args["location"], color: args["color"].presence || "#34D399",
        recurring: args.key?("recurring") ? args["recurring"] : true,
        repeat_days: args["repeat_days"] || [],
        repeat_until: args["repeat_until"].present? ? (Date.parse(args["repeat_until"]) rescue nil) : nil
      )
      if shift.save
        { success: true, shift_id: shift.id, title: shift.title, start_date: shift.start_date.iso8601 }
      else
        { success: false, errors: shift.errors.full_messages }
      end
    end

    def edit_work_shift(args)
      shift_id = args["shift_id"].to_s
      return { success: false, errors: [ "Work shift ID is required" ] } if shift_id.blank?

      if in_draft_mode?
        if shift_id.start_with?("d_")
          op = draft&.find_create_op("shift", shift_id)
          return { success: false, errors: [ "Draft shift not found" ] } unless op
          base = op.fetch("data", {})
          updates = filter_updates(args, %w[title description start_date start_time end_time location color recurring repeat_days repeat_until])
          merged = base.merge(updates)
          shift = @user.work_shifts.new(merged)
          return { success: false, errors: shift.errors.full_messages } unless shift.valid?
          return { success: false, errors: [ "Draft shift not found" ] } unless draft&.update_create("shift", shift_id, merged)
          return { success: true, shift_id: shift_id, title: merged["title"], refresh_draft_ui: true }
        end

        shift = @user.work_shifts.find_by(id: shift_id)
        return { success: false, errors: [ "Work shift not found" ] } unless shift
        updates = filter_updates(args, %w[title description start_date start_time end_time location color recurring repeat_days repeat_until])
        shift.assign_attributes(updates.transform_keys(&:to_sym))
        return { success: false, errors: shift.errors.full_messages } unless shift.valid?
        draft.add_update("shift", shift.id, updates)
        return { success: true, shift_id: shift.id, title: shift.title, refresh_draft_ui: true }
      end

      shift = @user.work_shifts.find_by(id: shift_id)
      return { success: false, errors: [ "Work shift not found" ] } unless shift
      updates = {}
      updates[:title]        = args["title"]                                     if args["title"].present?
      updates[:description]  = args["description"]                               if args.key?("description")
      updates[:start_date]   = (Date.parse(args["start_date"]) rescue nil)       if args["start_date"].present?
      updates[:start_time]   = args["start_time"]                               if args["start_time"].present?
      updates[:end_time]     = args["end_time"]                                  if args["end_time"].present?
      updates[:location]     = args["location"]                                  if args.key?("location")
      updates[:color]        = args["color"]                                     if args["color"].present?
      updates[:recurring]    = args["recurring"]                                 if args.key?("recurring")
      updates[:repeat_days]  = args["repeat_days"]                              if args.key?("repeat_days")
      updates[:repeat_until] = args["repeat_until"].present? ? (Date.parse(args["repeat_until"]) rescue nil) : nil if args.key?("repeat_until")
      if shift.update(updates)
        { success: true, shift_id: shift.id, title: shift.title }
      else
        { success: false, errors: shift.errors.full_messages }
      end
    end

    def delete_work_shift(args)
      shift_id = args["shift_id"].to_s
      return { success: false, errors: [ "Work shift ID is required" ] } if shift_id.blank?

      if in_draft_mode?
        if shift_id.start_with?("d_")
          deleted = draft&.delete_create("shift", shift_id)
          return { success: false, errors: [ "Draft shift not found" ] } unless deleted
          return { success: true, shift_id: shift_id, refresh_draft_ui: true }
        end
        shift = @user.work_shifts.find_by(id: shift_id)
        return { success: false, errors: [ "Work shift not found" ] } unless shift
        draft.add_delete("shift", shift.id)
        return { success: true, shift_id: shift.id, title: shift.title, refresh_draft_ui: true }
      end

      shift = @user.work_shifts.find_by(id: shift_id)
      return { success: false, errors: [ "Work shift not found" ] } unless shift
      title = shift.title
      shift.destroy
      { success: true, shift_id: shift_id, title: title }
    end

    def show_schedule(args)
      start_date  = args["start_date"].present? ? Date.parse(args["start_date"]) : Date.current
      week_start  = start_date.beginning_of_week
      range_end   = (week_start + 13.days).end_of_day
      occurrences = @ctx.occurrences_fetcher.call(week_start.beginning_of_day, range_end, draft: draft)
      { success: true, partial: { name: "ai_chat/ai_schedule", locals: { occurrences: occurrences, start_date: start_date } } }
    end

    def show_create_form(args)
      attrs = { color: args["color"].presence || "#34D399" }
      attrs[:title]            = args["title"]            if args["title"].present?
      attrs[:description]      = args["description"]      if args["description"].present?
      attrs[:location]         = args["location"]         if args["location"].present?
      attrs[:duration_minutes] = args["duration_minutes"] if args["duration_minutes"].present?
      attrs[:starts_at]        = (Time.zone.parse(args["starts_at"]) rescue nil) if args["starts_at"].present?
      attrs[:ends_at]          = (Time.zone.parse(args["ends_at"])   rescue nil) if args["ends_at"].present?
      event = @user.events.new(attrs)
      { success: true, partial: { name: "ai_chat/ai_create_form", locals: { event: event } } }
    end

    def show_draft_picker
      drafts = @user.calendar_drafts.recent.to_a
      { success: true, partial: { name: "ai_chat/draft_select_form", locals: { drafts: drafts, start_date: Date.current.iso8601 } } }
    end

    def propose_routine(args)
      intent = args.slice(
        "study_hours_per_week", "deep_work_hours_per_week", "errand_hours_per_week",
        "preferred_dayparts", "avoid", "keep_free"
      )

      if intent.slice("study_hours_per_week", "deep_work_hours_per_week", "errand_hours_per_week")
                .values.all? { |v| v.to_f <= 0 }
        return { success: false, errors: [ "No hours specified — provide at least one of study/deep_work/errand hours." ] }
      end

      busy   = busy_by_wday_for_week
      result = Scheduling::BlockRoutine.new(user: @user, intent: intent, busy_by_wday: busy).call

      created = []
      ActiveRecord::Base.transaction do
        @user.blocks.proposed.delete_all
        created = result[:blocks].map do |b|
          @user.blocks.create!(label: b.label, color: b.color, repeat_days: b.repeat_days,
                               start_minute: b.start_minute, end_minute: b.end_minute, status: "proposed")
        end
      end

      { success: true, proposed_count: created.size, unplaceable: result[:unplaceable], review_path: "/blocks" }
    rescue ActiveRecord::RecordInvalid => e
      { success: false, errors: [ "Could not save routine: #{e.message}" ] }
    end

    # Builds { wday => [[start_min, end_min], ...] } of fixed commitments for the
    # current week from the occurrences fetcher (classes, shifts, events).
    def busy_by_wday_for_week
      week_start = Date.current.beginning_of_week(:monday).beginning_of_day
      week_end   = (Date.current.beginning_of_week(:monday) + 6.days).end_of_day
      occurrences = @ctx.occurrences_fetcher.call(week_start, week_end, draft: nil)

      busy = Hash.new { |h, k| h[k] = [] }
      occurrences.each do |occ|
        next unless occ.respond_to?(:starts_at) && occ.respond_to?(:ends_at) && occ.starts_at && occ.ends_at
        wday  = occ.starts_at.wday
        s_min = occ.starts_at.hour * 60 + occ.starts_at.min
        raw_e = occ.ends_at.hour * 60 + occ.ends_at.min
        e_min = occ.ends_at.to_date > occ.starts_at.to_date ? 24 * 60 : raw_e
        busy[wday] << [ s_min, e_min ]
      end
      busy
    end

    # Builds a string-keyed hash of only the args keys that were explicitly
    # provided. Used for update operations where we must distinguish
    # "key not sent" from "key sent as nil".
    def filter_updates(args, keys)
      keys.each_with_object({}) do |k, h|
        h[k] = args[k] if args.key?(k)
      end
    end
  end
end
