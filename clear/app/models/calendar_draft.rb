# frozen_string_literal: true

class CalendarDraft < ApplicationRecord
  MAX_DRAFTS_PER_USER = 5
  belongs_to :user
  scope :recent, -> { order(created_at: :asc, id: :asc) }

  validates :name, presence: true, length: { maximum: 32 }
  validate :user_draft_limit, on: :create

  # Operations format (model can be "event", "course", "shift", or "task"):
  #   create: { "type" => "create", "model" => "event"|"course"|"shift"|"task", "temp_id" => "d_abc", "data" => {...} }
  #   update: { "type" => "update", "model" => "event"|"course"|"shift"|"task", "id" => 42, "data" => {...} }
  #   delete: { "type" => "delete", "model" => "event"|"course"|"shift"|"task", "id" => 42 }

  # Lightweight struct used to represent draft-created events in the calendar preview.
  # Must respond to the same interface that _calendar.html.erb expects from an Event.
  DraftEventProxy = Struct.new(
    :temp_id, :title, :starts_at, :ends_at, :color, :location, :description,
    keyword_init: true
  ) do
    def id = temp_id
    def to_param = temp_id
    def persisted? = true
    def to_model = self
    def model_name = Event.model_name
    def recurring = false
    def recurring? = false

    def contrast_text_color
      Event.new(color: color.presence || "#34D399").contrast_text_color
    end
  end

  # Lightweight struct used to represent draft-created courses in the calendar preview.
  DraftCourseProxy = Struct.new(
    :temp_id, :title, :start_time, :end_time, :color, :location, :description,
    :professor, :repeat_days, :start_date, :end_date,
    keyword_init: true
  ) do
    def id = temp_id
    def to_param = temp_id
    def persisted? = true
    def to_model = self
    def model_name = Course.model_name

    def contrast_text_color
      Course.new(color: color.presence || "#34D399").contrast_text_color
    end
  end

  # Lightweight struct used to represent draft-created shifts in the calendar preview.
  DraftShiftProxy = Struct.new(
    :temp_id, :title, :start_date, :start_time, :end_time, :color, :location, :description,
    :recurring, :repeat_until,
    keyword_init: true
  ) do
    def id = temp_id
    def to_param = temp_id
    def persisted? = true
    def to_model = self
    def model_name = WorkShift.model_name
    def recurring = false

    def contrast_text_color
      WorkShift.new(color: color.presence || "#34D399").contrast_text_color
    end
  end

  # Lightweight struct used to represent draft-created tasks in the calendar preview.
  DraftTaskProxy = Struct.new(
    :temp_id, :title, :scheduled_at, :duration_minutes, :color,
    keyword_init: true
  ) do
    def id            = temp_id
    def to_param      = temp_id
    def persisted?    = true
    def to_model      = self
    def model_name    = Task.model_name
    def location      = nil
    def description   = nil
    def course_item   = nil

    def contrast_text_color
      Task.new(color: color.presence || "#34D399").contrast_text_color
    end

    def occurrences_between(range_start, range_end)
      return [] unless scheduled_at
      starts = scheduled_at
      ends   = scheduled_at + duration_minutes.to_i.minutes
      return [] unless starts <= range_end && ends >= range_start
      [ Task::Occurrence.new(event: self, starts_at: starts, ends_at: ends, draft_status: "created") ]
    end
  end

  # --------------------------------------------------------------------------
  # Mutation helpers
  # --------------------------------------------------------------------------

  def add_create(model, data)
    temp_id = "d_#{SecureRandom.hex(4)}"
    update!(operations: operations + [ {
      "type" => "create", "model" => model,
      "temp_id" => temp_id, "data" => data.stringify_keys
    } ])
    temp_id
  end

  def add_update(model, id, data)
    # Collapse repeated updates to the same record into a single entry
    filtered = operations.reject { |op| op["type"] == "update" && op["model"] == model && op["id"] == id }
    update!(operations: filtered + [ {
      "type" => "update", "model" => model, "id" => id, "data" => data.stringify_keys
    } ])
  end

  # Stage a single-occurrence reschedule (drag of one instance of a recurring
  # record while in draft mode). Collapses repeats for the same occurrence.
  def add_reschedule_occurrence(model, id, occurrence_date, data)
    date_str = occurrence_date.to_s
    filtered = operations.reject do |op|
      op["type"] == "reschedule_occurrence" && op["model"] == model &&
        op["id"] == id && op["occurrence_date"] == date_str
    end
    update!(operations: filtered + [ {
      "type" => "reschedule_occurrence", "model" => model, "id" => id,
      "occurrence_date" => date_str, "data" => data.stringify_keys
    } ])
  end

  # Drop a staged single-occurrence reschedule (e.g. the occurrence was dragged
  # back onto the slot its rule already produces, making the op redundant).
  def remove_reschedule_occurrence(model, id, occurrence_date)
    date_str = occurrence_date.to_s
    filtered = operations.reject do |op|
      op["type"] == "reschedule_occurrence" && op["model"] == model &&
        op["id"] == id && op["occurrence_date"] == date_str
    end
    update!(operations: filtered) if filtered.size != operations.size
  end

  def add_delete(model, id)
    # Drop any pending update for this record, then queue the delete
    filtered = operations.reject { |op| op["model"] == model && op["id"] == id }
    update!(operations: filtered + [ { "type" => "delete", "model" => model, "id" => id } ])
  end

  # For the edit route to work on newly drafted occurrences. Makes d_<id> records.
  def find_create_op(model, temp_id)
    operations.find do |op|
      op["type"] == "create" && op["model"] == model && op["temp_id"].to_s == temp_id.to_s
    end
  end

  # Used so the popover doesn't show old values when updated while in Draft Mode
  def find_update_op(model, id)
    operations.reverse_each.find do |op|
      op["type"] == "update" && op["model"] == model && op["id"].to_i == id.to_i
    end
  end

  # For being able to edit newly created drafted occurrences
  def update_create(model, temp_id, data)
    updated = false
    next_ops = operations.map do |op|
      if op["type"] == "create" && op["model"] == model && op["temp_id"].to_s == temp_id.to_s
        updated = true
        op.merge("data" => data.stringify_keys)
      else
        op
      end
    end

    update!(operations: next_ops) if updated
    updated
  end

  # For being able to delete created drafted occurrences
  def delete_create(model, temp_id)
    removed = false
    next_ops = operations.reject do |op|
      match = op["type"] == "create" && op["model"] == model && op["temp_id"].to_s == temp_id.to_s
      removed ||= match
      match
    end

    update!(operations: next_ops) if removed
    removed
  end

  # --------------------------------------------------------------------------
  # Apply / Discard
  # --------------------------------------------------------------------------

  def apply!(user)
    prev = operations.dup
    ActiveRecord::Base.transaction do
      operations.each do |op|
        case op["model"]
        when "event"
          case op["type"]
          when "create" then user.events.create!(op["data"].symbolize_keys)
          when "update" then user.events.find(op["id"]).update!(op["data"].symbolize_keys)
          when "delete" then user.events.find(op["id"]).destroy!
          when "reschedule_occurrence"
            event = user.events.find(op["id"])
            ex = event.event_exceptions.find_or_initialize_by(excluded_date: Date.parse(op["occurrence_date"]))
            ex.update!(
              override_starts_at: op["data"]["starts_at"],
              override_ends_at: op["data"]["ends_at"]
            )
          end
        when "course"
          case op["type"]
          when "create" then user.courses.create!(op["data"].symbolize_keys)
          when "update" then user.courses.find(op["id"]).update!(op["data"].symbolize_keys)
          when "delete" then user.courses.find(op["id"]).destroy!
          end
        when "shift"
          case op["type"]
          when "create" then user.work_shifts.create!(op["data"].symbolize_keys)
          when "update" then user.work_shifts.find(op["id"]).update!(op["data"].symbolize_keys)
          when "delete" then user.work_shifts.find(op["id"]).destroy!
          end
        when "task"
          case op["type"]
          when "create" then user.tasks.create!(op["data"].symbolize_keys)
          when "update" then user.tasks.find(op["id"]).update!(op["data"].symbolize_keys)
          when "delete" then user.tasks.find(op["id"]).destroy!
          end
        end
      end
    end
    update!(operations: [], previous_operations: prev)
  end

  def discard!
    update!(previous_operations: operations, operations: [])
  end

  def operation_count
    operations.size
  end

  # --------------------------------------------------------------------------
  # Preview: merge draft ops into a real occurrence list
  # --------------------------------------------------------------------------

  def build_preview_occurrences(occurrences, range_start, range_end)
    # ── Event draft ops ──
    event_deleted_ids = operations
      .select { |op| op["type"] == "delete" && op["model"] == "event" }
      .map { |op| op["id"] }

    event_update_ops = operations
      .select { |op| op["type"] == "update" && op["model"] == "event" }
      .index_by { |op| op["id"] }

    event_create_ops = operations.select { |op| op["type"] == "create" && op["model"] == "event" }

    # Single-occurrence reschedules (drag of one instance of a recurring event in
    # draft). Suppress the original-date occurrence; inject the moved one below.
    event_reschedule_ops = operations.select { |op| op["type"] == "reschedule_occurrence" && op["model"] == "event" }
    event_reschedule_dates = Hash.new { |h, k| h[k] = {} }
    event_reschedule_ops.each { |op| event_reschedule_dates[op["id"]][op["occurrence_date"]] = op }
    event_by_id = {}

    # ── Course draft ops ──
    course_deleted_ids = operations
      .select { |op| op["type"] == "delete" && op["model"] == "course" }
      .map { |op| op["id"] }

    course_update_ops = operations
      .select { |op| op["type"] == "update" && op["model"] == "course" }
      .index_by { |op| op["id"] }

    course_create_ops = operations.select { |op| op["type"] == "create" && op["model"] == "course" }

    # ── Workshifts draft ops ──
    shift_deleted_ids = operations
      .select { |op| op["type"] == "delete" && op["model"] == "shift" }
      .map { |op| op["id"] }

    shift_update_ops = operations
      .select { |op| op["type"] == "update" && op["model"] == "shift" }
      .index_by { |op| op["id"] }

    shift_create_ops = operations.select { |op| op["type"] == "create" && op["model"] == "shift" }

    # ── Task draft ops ──
    task_deleted_ids = operations
      .select { |op| op["type"] == "delete" && op["model"] == "task" }
      .map { |op| op["id"] }

    task_update_ops = operations
      .select { |op| op["type"] == "update" && op["model"] == "task" }
      .index_by { |op| op["id"] }

    task_create_ops = operations.select { |op| op["type"] == "create" && op["model"] == "task" }

    # Build updated objects once per record id, not once per occurrence
    updated_event_cache  = {}
    updated_course_cache = {}
    updated_shift_cache  = {}
    updated_task_cache   = {}
    rebuilt_event_occurrences = {}
    rebuilt_course_occurrences = {}
    rebuilt_shift_occurrences = {}

    result = occurrences.map do |occ|
      record = occ.respond_to?(:event) ? occ.event : occ
      model  = record.model_name.singular

      if model == "event"
        event_by_id[record.id] ||= record
        next if rebuilt_event_occurrences.key?(record.id)

        # A single-occurrence reschedule suppresses the rule's slot on that date;
        # the moved occurrence is injected after the loop.
        if event_reschedule_dates[record.id].key?(occ.starts_at.to_date.to_s)
          next
        end

        if event_deleted_ids.include?(record.id)
          next Event::Occurrence.new(
            event: record, starts_at: occ.starts_at, ends_at: occ.ends_at,
            draft_status: "deleted"
          )
        end

        if (update_op = event_update_ops[record.id])
          updated = updated_event_cache[record.id] ||= begin
            e = Event.new(record.attributes.except("id", "created_at", "updated_at").merge(update_op["data"]))
            e.id = record.id
            e.instance_variable_set(:@new_record, false)
            e
          end

          # Rebuild from the recurrence rule when its shape changes — recurring
          # flips, or (mirroring courses/shifts) the weekdays or end date move.
          # This covers scope=all (weekday shift) and scope=following (capped
          # repeat_until) reschedules staged as updates.
          if record.recurring? != updated.recurring? ||
             (updated.recurring? &&
              (Array(record.repeat_days).map(&:to_s).sort != Array(updated.repeat_days).map(&:to_s).sort ||
               record.repeat_until != updated.repeat_until))
            rebuilt_event_occurrences[record.id] = updated.occurrences_between(range_start, range_end).map do |updated_occ|
              Event::Occurrence.new(event: updated, starts_at: updated_occ.starts_at, ends_at: updated_occ.ends_at, draft_status: "updated")
            end
            next
          end

          if record.recurring?
            occ_date      = occ.starts_at.to_date
            new_time      = updated.starts_at.in_time_zone
            new_start     = Time.zone.local(occ_date.year, occ_date.month, occ_date.day,
                                            new_time.hour, new_time.min, new_time.sec)
            orig_duration = (record.ends_at && record.starts_at) ? (record.ends_at - record.starts_at) : nil
            new_duration  = (updated.ends_at && updated.starts_at) ? (updated.ends_at - updated.starts_at) : orig_duration
            new_end       = new_duration ? (new_start + new_duration) : nil

            next Event::Occurrence.new(event: updated, starts_at: new_start, ends_at: new_end, draft_status: "updated")
          else
            next Event::Occurrence.new(
              event: updated,
              starts_at: updated.starts_at || occ.starts_at,
              ends_at: updated.ends_at,
              draft_status: "updated"
            )
          end
        end

      elsif model == "course"
        next if rebuilt_course_occurrences.key?(record.id)

        if course_deleted_ids.include?(record.id)
          next Course::Occurrence.new(
            event: record, starts_at: occ.starts_at, ends_at: occ.ends_at,
            draft_status: "deleted"
          )
        end

        if (update_op = course_update_ops[record.id])
          updated = updated_course_cache[record.id] ||= begin
            c = Course.new(record.attributes.except("id", "created_at", "updated_at").merge(update_op["data"]))
            c.id = record.id
            c.instance_variable_set(:@new_record, false)
            c
          end

          if Array(record.repeat_days).map(&:to_s).sort != Array(updated.repeat_days).map(&:to_s).sort ||
             record.start_date != updated.start_date ||
             record.end_date != updated.end_date
            rebuilt_course_occurrences[record.id] = updated.occurrences_between(range_start, range_end).map do |updated_occ|
              Course::Occurrence.new(event: updated, starts_at: updated_occ.starts_at, ends_at: updated_occ.ends_at, draft_status: "updated")
            end
            next
          end

          # Courses are always recurring — keep the occurrence calendar date,
          # update time-of-day and other attributes in the preview.
          occ_date  = occ.starts_at.to_date
          new_start = Time.zone.local(occ_date.year, occ_date.month, occ_date.day,
                                      updated.start_time.hour, updated.start_time.min, updated.start_time.sec)
          new_end   = if updated.end_time.present?
                        Time.zone.local(occ_date.year, occ_date.month, occ_date.day,
                                        updated.end_time.hour, updated.end_time.min, updated.end_time.sec)
          end

          next Course::Occurrence.new(event: updated, starts_at: new_start, ends_at: new_end, draft_status: "updated")
        end
      elsif model == "work_shift"
        next if rebuilt_shift_occurrences.key?(record.id)

        if shift_deleted_ids.include?(record.id)
          next WorkShift::Occurrence.new(
            event: record, starts_at: occ.starts_at, ends_at: occ.ends_at,
            draft_status: "deleted"
          )
        end

        if (update_op = shift_update_ops[record.id])
          updated = updated_shift_cache[record.id] ||= begin
            ws = WorkShift.new(record.attributes.except("id", "created_at", "updated_at").merge(update_op["data"]))
            ws.id = record.id
            ws.instance_variable_set(:@new_record, false)
            ws
          end

          # Workshifts uses strings instead of arrays, so it is a bit more complicated
          if record.recurring? != updated.recurring? ||
             (updated.recurring? &&
              (Array(record.repeat_days).map(&:to_s).sort != Array(updated.repeat_days).map(&:to_s).sort ||
               record.repeat_until != updated.repeat_until ||
               record.start_date != updated.start_date))
            rebuilt_shift_occurrences[record.id] = updated.occurrences_between(range_start, range_end).map do |updated_occ|
              WorkShift::Occurrence.new(event: updated, starts_at: updated_occ.starts_at, ends_at: updated_occ.ends_at, draft_status: "updated")
            end
            next
          end

          occ_date  = occ.starts_at.to_date
          new_start = Time.zone.local(occ_date.year, occ_date.month, occ_date.day,
                                      updated.start_time.hour, updated.start_time.min, updated.start_time.sec)
          new_end   = Time.zone.local(occ_date.year, occ_date.month, occ_date.day,
                                      updated.end_time.hour, updated.end_time.min, updated.end_time.sec)

          next WorkShift::Occurrence.new(event: updated, starts_at: new_start, ends_at: new_end, draft_status: "updated")
        end
      elsif model == "task"
        # Tasks are non-recurring: no rebuilt-occurrences deduplication needed.
        if task_deleted_ids.include?(record.id)
          next Task::Occurrence.new(
            event: record, starts_at: occ.starts_at, ends_at: occ.ends_at,
            draft_status: "deleted"
          )
        end

        if (update_op = task_update_ops[record.id])
          updated = updated_task_cache[record.id] ||= begin
            t = Task.new(record.attributes.except("id", "created_at", "updated_at").merge(update_op["data"]))
            t.id = record.id
            t.instance_variable_set(:@new_record, false)
            t
          end
          new_start = updated.scheduled_at || occ.starts_at
          new_end   = new_start + updated.duration_minutes.to_i.minutes
          next Task::Occurrence.new(event: updated, starts_at: new_start, ends_at: new_end,
                                    draft_status: "updated")
        end
      end
      occ
    end.compact
    rebuilt_event_occurrences.each_value { |rows| result.concat(rows) }

    # Inject moved single-occurrence reschedules whose new start falls in range.
    event_reschedule_ops.each do |op|
      event = event_by_id[op["id"]] ||= Event.find_by(id: op["id"])
      next unless event && !event_deleted_ids.include?(op["id"])

      data = op["data"]
      new_start = (Time.zone.parse(data["starts_at"].to_s) rescue nil)
      next unless new_start && new_start >= range_start && new_start <= range_end
      new_end = data["ends_at"].present? ? (Time.zone.parse(data["ends_at"].to_s) rescue nil) : nil

      result << Event::Occurrence.new(event: event, starts_at: new_start, ends_at: new_end,
                                      draft_status: "updated", override_date: Date.parse(op["occurrence_date"]))
    end
    rebuilt_course_occurrences.each_value { |rows| result.concat(rows) }
    rebuilt_shift_occurrences.each_value { |rows| result.concat(rows) }

    # ── Draft-created tasks ──
    task_create_ops.each do |op|
      data         = op["data"].symbolize_keys
      scheduled_at = Time.zone.parse(data[:scheduled_at].to_s) rescue nil
      next unless scheduled_at

      duration = data[:duration_minutes].to_i
      duration = 30 if duration <= 0

      proxy = DraftTaskProxy.new(
        temp_id:          op["temp_id"],
        title:            data[:title].presence || "(Draft Task)",
        scheduled_at:     scheduled_at,
        duration_minutes: duration,
        color:            data[:color].presence || "#34D399"
      )

      ends_at = scheduled_at + duration.minutes
      next if scheduled_at > range_end || ends_at < range_start

      result << Task::Occurrence.new(
        event: proxy, starts_at: scheduled_at, ends_at: ends_at,
        draft_status: "created"
      )
    end

    # ── Draft-created events ──
    event_create_ops.each do |op|
      data = op["data"].symbolize_keys
      starts_at = Time.zone.parse(data[:starts_at].to_s) rescue nil
      next unless starts_at

      ends_at = data[:ends_at].present? ? (Time.zone.parse(data[:ends_at].to_s) rescue nil) : nil
      ends_at ||= starts_at + 1.hour
      recurring = ActiveModel::Type::Boolean.new.cast(data[:recurring])
      repeat_days = Array(data[:repeat_days]).reject(&:blank?).map(&:to_i)
      repeat_until = data[:repeat_until].present? ? (Date.parse(data[:repeat_until].to_s) rescue nil) : nil

      proxy = DraftEventProxy.new(
        temp_id: op["temp_id"],
        title: data[:title].presence || "(Draft Event)",
        starts_at: starts_at,
        ends_at: ends_at,
        color: data[:color].presence || "#34D399",
        location: data[:location],
        description: data[:description]
      )

      if recurring && repeat_days.any? && repeat_until.present?
        duration = (starts_at && ends_at) ? (ends_at - starts_at) : nil
        window_start = [ range_start.to_date, starts_at.to_date ].max
        window_end = [ range_end.to_date, repeat_until ].min
        next if window_end < window_start

        d = window_start
        while d <= window_end
          if repeat_days.include?(d.wday)
            occ_start = Time.zone.local(d.year, d.month, d.day, starts_at.hour, starts_at.min, starts_at.sec)
            occ_end = duration ? (occ_start + duration) : nil
            result << Event::Occurrence.new(
              event: proxy, starts_at: occ_start, ends_at: occ_end,
              draft_status: "created"
            )
          end
          d += 1.day
        end
      else
        next if starts_at < range_start || starts_at > range_end

        result << Event::Occurrence.new(
          event: proxy, starts_at: starts_at, ends_at: ends_at,
          draft_status: "created"
        )
      end
    end

    # ── Draft-created courses ──
    course_create_ops.each do |op|
      data = op["data"].symbolize_keys
      start_time = Time.zone.parse(data[:start_time].to_s) rescue nil
      next unless start_time

      end_time = data[:end_time].present? ? (Time.zone.parse(data[:end_time].to_s) rescue nil) : nil
      repeat_days = Array(data[:repeat_days]).reject(&:blank?).map(&:to_i)
      course_start = data[:start_date].present? ? (Date.parse(data[:start_date].to_s) rescue nil) : nil
      course_end   = data[:end_date].present? ? (Date.parse(data[:end_date].to_s) rescue nil) : nil

      proxy = DraftCourseProxy.new(
        temp_id: op["temp_id"],
        title: data[:title].presence || "(Draft Course)",
        start_time: start_time,
        end_time: end_time,
        color: data[:color].presence || "#34D399",
        location: data[:location],
        description: data[:description],
        professor: data[:professor],
        repeat_days: repeat_days,
        start_date: course_start,
        end_date: course_end
      )

      # Generate occurrences for the draft course within the visible range
      window_start = [ range_start.to_date, course_start ].compact.max
      window_end   = [ range_end.to_date, course_end ].compact.min
      next if window_end < window_start

      d = window_start
      while d <= window_end
        if repeat_days.include?(d.wday)
          occ_start = Time.zone.local(d.year, d.month, d.day, start_time.hour, start_time.min, start_time.sec)
          occ_end   = end_time ? Time.zone.local(d.year, d.month, d.day, end_time.hour, end_time.min, end_time.sec) : nil

          result << Course::Occurrence.new(
            event: proxy, starts_at: occ_start, ends_at: occ_end,
            draft_status: "created"
          )
        end
        d += 1.day
      end
    end

    # ── Draft-created shifts ──
    shift_create_ops.each do |op|
      data = op["data"].symbolize_keys
      start_date = data[:start_date].present? ? (Date.parse(data[:start_date].to_s) rescue nil) : nil
      start_time = Time.zone.parse(data[:start_time].to_s) rescue nil
      end_time   = Time.zone.parse(data[:end_time].to_s) rescue nil
      recurring = ActiveModel::Type::Boolean.new.cast(data[:recurring])
      repeat_days = Array(data[:repeat_days]).reject(&:blank?).map(&:to_i)
      repeat_until = data[:repeat_until].present? ? (Date.parse(data[:repeat_until].to_s) rescue nil) : nil
      next unless start_date && start_time && end_time

      proxy = DraftShiftProxy.new(
        temp_id: op["temp_id"],
        title: data[:title].presence || "(Draft Shift)",
        start_date: start_date,
        start_time: start_time,
        end_time: end_time,
        color: data[:color].presence || "#34D399",
        location: data[:location],
        description: data[:description],
        recurring: recurring,
        repeat_until: repeat_until
      )

      if recurring && repeat_days.any?
        window_start = [ range_start.to_date, start_date ].max
        window_end = range_end.to_date
        window_end = [ window_end, repeat_until ].min if repeat_until.present?
        next if window_end < window_start

        d = window_start
        while d <= window_end
          if repeat_days.include?(d.wday)
            occ_start = Time.zone.local(d.year, d.month, d.day, start_time.hour, start_time.min, start_time.sec)
            occ_end = Time.zone.local(d.year, d.month, d.day, end_time.hour, end_time.min, end_time.sec)
            result << WorkShift::Occurrence.new(
              event: proxy, starts_at: occ_start, ends_at: occ_end,
              draft_status: "created"
            )
          end
          d += 1.day
        end
      else
        next if start_date < range_start.to_date || start_date > range_end.to_date

        occ_start = Time.zone.local(start_date.year, start_date.month, start_date.day,
                                    start_time.hour, start_time.min, start_time.sec)
        occ_end   = Time.zone.local(start_date.year, start_date.month, start_date.day,
                                    end_time.hour, end_time.min, end_time.sec)

        result << WorkShift::Occurrence.new(
          event: proxy, starts_at: occ_start, ends_at: occ_end,
          draft_status: "created"
        )
      end
    end

    result.sort_by(&:starts_at)
  end

  private

  def user_draft_limit
    return unless user.present?
    return if user.calendar_drafts.where.not(id: id).size < MAX_DRAFTS_PER_USER

    errors.add(:base, "You can only have up to #{MAX_DRAFTS_PER_USER} drafts.")
  end
end
