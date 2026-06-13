module Ai
  class SystemPrompt
    def self.build(user:, draft:, drafts:)
      new(user: user, draft: draft, drafts: drafts).build
    end

    def initialize(user:, draft:, drafts:)
      @user   = user
      @draft  = draft
      @drafts = drafts
    end

    def build
      parts = []
      parts << "You are a helpful academic assistant for a calendar and course management app called CLEAR."
      parts << "The user's name is #{name} (email: #{@user.email}). Address them by their first name."
      parts << "Today's date is #{Date.current.strftime('%A, %B %d, %Y')}."

      if @draft.present?
        parts << "Current draft is \"#{@draft.name}\" (ID: #{@draft.id})."
      else
        parts << "Current draft is none (Main Calendar)."
      end

      if @drafts.any?
        parts << "Available drafts: " + @drafts.map { |d| "#{d.name} (ID: #{d.id})" }.join(", ")
      end

      courses = @user.courses.includes(:course_items)
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
        if @draft.present?
          @draft.operations.select { |o| o["type"] == "create" && o["model"] == "course" }.each do |op|
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

      upcoming_events = @user.events
        .where("starts_at >= ? AND starts_at <= ?", Time.current, 14.days.from_now)
        .order(:starts_at)
        .limit(30)

      if upcoming_events.any?
        personal, group = upcoming_events.partition { |e| e.project_id.blank? }

        if personal.any?
          event_lines = personal.map do |e|
            line = "- [ID:#{e.id}] #{e.title} on #{e.starts_at.strftime('%a %b %d at %l:%M%P')}"
            line += " at #{e.location}" if e.location.present?
            line += " — #{e.description}" if e.description.present?
            line
          end
          if @draft.present?
            @draft.operations.select { |o| o["type"] == "create" && o["model"] == "event" }.each do |op|
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

      upcoming_items = CourseItem
        .where(course: @user.courses)
        .where("due_at >= ? AND due_at <= ?", Time.current, 14.days.from_now)
        .order(:due_at)
        .limit(30)

      if upcoming_items.any?
        item_lines = upcoming_items.map do |ci|
          "- #{ci.display_title} due #{ci.due_at.strftime('%a %b %d at %l:%M%P')}"
        end
        parts << "\nUpcoming assignments & deadlines (next 14 days):\n#{item_lines.join("\n")}"
      end

      work_shifts = @user.work_shifts.active.ordered
      if work_shifts.any?
        shift_lines = work_shifts.map do |s|
          line = "- [ID:#{s.id}] #{s.title} #{s.formatted_time_range}"
          line += " (#{s.repeat_days_labels})" if s.recurring? && s.repeat_days.any?
          line += " until #{s.repeat_until.strftime('%b %d, %Y')}" if s.repeat_until.present?
          line += " at #{s.location}" if s.location.present?
          line
        end
        if @draft.present?
          @draft.operations.select { |o| o["type"] == "create" && o["model"] == "shift" }.each do |op|
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

      blocked = build_blocked_slots(upcoming_events, @user.courses.includes(:course_items), work_shifts)
      if blocked.any?
        blocked_lines = blocked.sort.map { |day, slots| "  #{day.strftime("%a %b %-d")}: #{slots.sort.join(", ")}" }
        parts << "\nOccupied time slots — do NOT schedule anything overlapping these:\n#{blocked_lines.join("\n")}"
      end

      if @draft.present?
        draft_lines = build_draft_lines
        if draft_lines.any?
          parts << "\nThis draft (\"#{@draft.name}\") has the following pending changes on top of the main calendar:\n#{draft_lines.join("\n")}"
          parts << "Treat these draft changes as the user's current working schedule — additions are real commitments, " \
                   "removals are gone, and edits reflect the new values. Give advice, flag conflicts, and answer " \
                   "questions as if this is simply their calendar. Do NOT volunteer that something is a draft or mention " \
                   "the draft/main distinction unless the user explicitly asks to compare the draft against the main " \
                   "calendar or asks what will change when the draft is applied."
        else
          parts << "\nThis draft (\"#{@draft.name}\") has no pending changes yet — it currently mirrors the main calendar."
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

    private

    def name
      @user.email.split("@").first.gsub(/[._]/, " ").titleize
    end

    def build_blocked_slots(upcoming_events, courses, work_shifts)
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

      blocked
    end

    def build_draft_lines
      lines = []
      @draft.operations.each do |op|
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
          lines << line
        when "update"
          case model
          when "event"
            record = @user.events.find_by(id: op["id"])
            label  = record ? "\"#{record.title}\" [ID:#{op["id"]}]" : "event ID #{op["id"]}"
            changes = data.map do |k, v|
              k == "starts_at" ? "#{k}: #{(Time.zone.parse(v.to_s) rescue v)&.strftime("%a %b %-d at %-I:%M%P")}" : "#{k}: #{v}"
            end.join(", ")
            lines << "- EDIT event #{label} — #{changes}"
          when "shift"
            record = @user.work_shifts.find_by(id: op["id"])
            label  = record ? "\"#{record.title}\" [ID:#{op["id"]}]" : "shift ID #{op["id"]}"
            lines << "- EDIT work shift #{label} — #{data.map { |k, v| "#{k}: #{v}" }.join(", ")}"
          when "course"
            record = @user.courses.find_by(id: op["id"])
            label  = record ? "\"#{record.title}\" [ID:#{op["id"]}]" : "course ID #{op["id"]}"
            lines << "- EDIT course #{label} — #{data.map { |k, v| "#{k}: #{v}" }.join(", ")}"
          end
        when "delete"
          case model
          when "event"
            record = @user.events.find_by(id: op["id"])
            lines << "- REMOVE event: \"#{record&.title || "ID #{op["id"]}"}\" [ID:#{op["id"]}]"
          when "shift"
            record = @user.work_shifts.find_by(id: op["id"])
            lines << "- REMOVE work shift: \"#{record&.title || "ID #{op["id"]}"}\" [ID:#{op["id"]}]"
          when "course"
            record = @user.courses.find_by(id: op["id"])
            lines << "- REMOVE course: \"#{record&.title || "ID #{op["id"]}"}\" [ID:#{op["id"]}]"
          end
        end
      end
      lines
    end
  end
end
