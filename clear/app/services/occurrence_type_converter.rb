# frozen_string_literal: true

# Converts an Event / Course / WorkShift into one of the other two types.
# Used by the dashboard "Change type" action so users can fix imported
# occurrences that landed under the wrong model.
class OccurrenceTypeConverter
  TYPES = %w[event course work_shift].freeze

  Result = Struct.new(:success, :record, :errors, keyword_init: true) do
    alias_method :success?, :success
  end

  def self.call(source:, target_type:)
    new(source: source, target_type: target_type).call
  end

  def initialize(source:, target_type:)
    @source = source
    @target_type = target_type.to_s
    @source_kind = kind_of(@source)
  end

  def call
    return failure([ "Unknown target type" ]) unless TYPES.include?(@target_type)
    return failure([ "Already that type" ]) if @source_kind == @target_type

    target = build_target
    saved = false

    ActiveRecord::Base.transaction do
      saved = target.save
      raise ActiveRecord::Rollback unless saved
      @source.destroy!
    end

    if saved
      Result.new(success: true, record: target, errors: [])
    else
      Result.new(success: false, record: target, errors: target.errors.full_messages)
    end
  end

  private

  def failure(errors)
    Result.new(success: false, record: @source, errors: errors)
  end

  def kind_of(record)
    case record
    when Event then "event"
    when Course then "course"
    when WorkShift then "work_shift"
    end
  end

  def build_target
    attrs = common_attrs.merge(time_attrs).merge(recurrence_attrs)
    case @target_type
    when "event"      then @source.user.events.new(attrs)
    when "course"     then @source.user.courses.new(attrs)
    when "work_shift" then @source.user.work_shifts.new(attrs)
    end
  end

  def common_attrs
    {
      title: @source.title.presence || "Untitled",
      description: @source.description,
      color: @source.color,
      location: @source.location
    }
  end

  def time_attrs
    send("time_#{@source_kind}_to_#{@target_type}")
  end

  def recurrence_attrs
    send("recurrence_#{@source_kind}_to_#{@target_type}")
  end

  # ---- time mappings ---------------------------------------------------

  def time_event_to_work_shift
    starts = @source.starts_at
    ends   = @source.ends_at || (starts + (@source.duration_minutes || 60).minutes)
    { start_date: starts.to_date, start_time: starts, end_time: ends }
  end

  def time_event_to_course
    starts = @source.starts_at
    ends   = @source.ends_at || (starts + (@source.duration_minutes || 60).minutes)
    end_date = @source.recurring? ? (@source.repeat_until || starts.to_date) : starts.to_date
    { start_date: starts.to_date, end_date: end_date, start_time: starts, end_time: ends }
  end

  def time_course_to_event
    starts = combine(@source.start_date, @source.start_time)
    ends   = @source.end_time.present? ? combine(@source.start_date, @source.end_time) : nil
    { starts_at: starts, ends_at: ends }
  end

  def time_course_to_work_shift
    { start_date: @source.start_date, start_time: @source.start_time, end_time: @source.end_time }
  end

  def time_work_shift_to_event
    starts = combine(@source.start_date, @source.start_time)
    ends   = combine(@source.start_date, @source.end_time)
    { starts_at: starts, ends_at: ends }
  end

  def time_work_shift_to_course
    end_date = @source.repeat_until || @source.start_date
    { start_date: @source.start_date, end_date: end_date,
      start_time: @source.start_time, end_time: @source.end_time }
  end

  # ---- recurrence mappings --------------------------------------------

  def recurrence_event_to_work_shift
    {
      recurring: @source.recurring?,
      repeat_until: @source.repeat_until,
      repeat_days: Array(@source.repeat_days).map(&:to_s)
    }
  end

  def recurrence_event_to_course
    days = @source.recurring? ? Array(@source.repeat_days).map(&:to_i) : [ @source.starts_at.wday ]
    { repeat_days: days }
  end

  def recurrence_course_to_event
    {
      recurring: true,
      repeat_until: @source.end_date,
      repeat_days: Array(@source.repeat_days).map(&:to_i)
    }
  end

  def recurrence_course_to_work_shift
    {
      recurring: true,
      repeat_until: @source.end_date,
      repeat_days: Array(@source.repeat_days).map(&:to_s)
    }
  end

  def recurrence_work_shift_to_event
    {
      recurring: @source.recurring?,
      repeat_until: @source.repeat_until,
      repeat_days: Array(@source.repeat_days).map(&:to_i)
    }
  end

  def recurrence_work_shift_to_course
    days = Array(@source.repeat_days).map(&:to_i)
    days = [ @source.start_date.wday ] if days.empty?
    { repeat_days: days }
  end

  # ---------------------------------------------------------------------

  def combine(date, time)
    return nil if date.blank? || time.blank?
    Time.zone.local(date.year, date.month, date.day, time.hour, time.min, time.sec)
  end
end
